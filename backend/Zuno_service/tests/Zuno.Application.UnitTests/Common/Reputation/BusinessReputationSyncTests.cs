using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Common.Reputation;

/// <summary>
/// The periodic refresh: Rent figures copied in when the Rent API answers, kept when it does not, and
/// every business recalculated in batches either way.
/// </summary>
public class BusinessReputationSyncTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 10, 0, 0, TimeSpan.Zero);

    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IRentReputationClient> _rent = new();
    private readonly Mock<IBusinessReputationService> _reputation = new();
    private readonly List<List<Guid>> _recalculatedBatches = [];

    private readonly BusinessOwnerProfile _rentBusiness = new() { UserId = Guid.NewGuid() };
    private readonly BusinessOwnerProfile _serviceOnly = new()
    {
        UserId = Guid.NewGuid(), RentRatingSum = 8m, RentRatingCount = 2, RentSuccessfulOrders = 3,
    };

    public BusinessReputationSyncTests()
    {
        _db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From(_rentBusiness, _serviceOnly));
        _reputation
            .Setup(r => r.RecalculateAsync(It.IsAny<IReadOnlyList<BusinessOwnerProfile>>(), It.IsAny<CancellationToken>()))
            .Callback((IReadOnlyList<BusinessOwnerProfile> batch, CancellationToken _) =>
                _recalculatedBatches.Add([.. batch.Select(p => p.Id)]))
            .Returns(Task.CompletedTask);
    }

    private BusinessReputationSync Sync(int batchSize = 500)
    {
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);
        return new BusinessReputationSync(
            _db.Object, _rent.Object, _reputation.Object, clock.Object,
            Options.Create(new ReputationSyncSettings { BatchSize = batchSize }));
    }

    [Fact]
    public async Task RentAnswered_CopiesFigures_AndZeroesBusinessesItDoesNotList()
    {
        _rent.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync([new RentReputation(_rentBusiness.UserId, 12m, 3, 4)]);

        var updated = await Sync().RunAsync(default);

        updated.Should().Be(2);
        (_rentBusiness.RentRatingSum, _rentBusiness.RentRatingCount, _rentBusiness.RentSuccessfulOrders)
            .Should().Be((12m, 3, 4));
        _rentBusiness.RentReputationAt.Should().Be(Now);
        (_serviceOnly.RentRatingSum, _serviceOnly.RentRatingCount, _serviceOnly.RentSuccessfulOrders)
            .Should().Be((0m, 0, 0));
        _recalculatedBatches.SelectMany(b => b).Should().BeEquivalentTo([_rentBusiness.Id, _serviceOnly.Id]);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RentFailed_KeepsTheStoredFigures_ButStillRecalculatesEveryone()
    {
        _rent.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync((IReadOnlyList<RentReputation>?)null);

        await Sync().RunAsync(default);

        (_serviceOnly.RentRatingSum, _serviceOnly.RentRatingCount, _serviceOnly.RentSuccessfulOrders)
            .Should().Be((8m, 2, 3));
        _serviceOnly.RentReputationAt.Should().BeNull();
        _recalculatedBatches.SelectMany(b => b).Should().HaveCount(2);
    }

    [Fact]
    public async Task WorksThroughBusinessesInBatches_SavingEach()
    {
        _rent.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);

        var updated = await Sync(batchSize: 1).RunAsync(default);

        updated.Should().Be(2);
        _recalculatedBatches.Should().HaveCount(2).And.OnlyContain(b => b.Count == 1);
        _recalculatedBatches.SelectMany(b => b).Should().OnlyHaveUniqueItems();
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Fact]
    public async Task NoBusinesses_DoesNothing()
    {
        _db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From<BusinessOwnerProfile>());
        _rent.Setup(r => r.GetAllAsync(It.IsAny<CancellationToken>())).ReturnsAsync([]);

        (await Sync().RunAsync(default)).Should().Be(0);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
