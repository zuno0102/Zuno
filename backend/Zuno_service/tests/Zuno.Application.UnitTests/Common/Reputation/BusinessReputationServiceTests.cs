using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Common.Reputation;

/// <summary>
/// Recounting a business's standing and a service's stars from the rows that make them up.
/// </summary>
public class BusinessReputationServiceTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 10, 0, 0, TimeSpan.Zero);

    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly BusinessReputationService _sut;

    public BusinessReputationServiceTests()
    {
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);
        _sut = new BusinessReputationService(_db.Object, clock.Object, new TestPlatformSettings());

        _db.Setup(d => d.Bookings).Returns(TestDbSet.From<Domain.Entities.Booking>());
        _db.Setup(d => d.HiringPosts).Returns(TestDbSet.From<Domain.Entities.HiringPost>());
        _db.Setup(d => d.HiringPostApplications).Returns(TestDbSet.From<HiringPostApplication>());
    }

    private static Rating RatingOf(Guid businessId, Guid? serviceId, short score) => new()
    {
        BusinessOwnerProfileId = businessId,
        BusinessServiceId = serviceId,
        Score = score,
    };

    private static Domain.Entities.Booking CompletedBooking(Guid businessId) => new()
    {
        BusinessOwnerProfileId = businessId,
        BookingStatus = BookingStatus.Completed,
    };

    [Fact]
    public async Task Recalculate_TotalsServiceRatings_AndKeepsRentFigures()
    {
        var business = new BusinessOwnerProfile { RentRatingSum = 9m, RentRatingCount = 2, RentSuccessfulOrders = 1 };
        var other = Guid.NewGuid();
        _db.Setup(d => d.Ratings).Returns(TestDbSet.From(
            RatingOf(business.Id, Guid.NewGuid(), 5),
            RatingOf(business.Id, Guid.NewGuid(), 4),
            RatingOf(business.Id, null, 3),
            RatingOf(other, Guid.NewGuid(), 1)));
        _db.Setup(d => d.Bookings).Returns(TestDbSet.From(
            CompletedBooking(business.Id), CompletedBooking(business.Id), CompletedBooking(other)));

        await _sut.RecalculateAsync([business]);

        business.ServiceRatingSum.Should().Be(12m);
        business.ServiceRatingCount.Should().Be(3);
        business.CompletedJobCount.Should().Be(2);
        business.RentSuccessfulOrders.Should().Be(1);
        business.CustomerReviewCount.Should().Be(5);
        business.CustomerRatingAverage.Should().Be(4.1m); // (21 + 20) / 10
        business.LevelRecalculatedAt.Should().Be(Now);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Recalculate_ABatch_CountsEachBusinessOnItsOwn()
    {
        var first = new BusinessOwnerProfile();
        var second = new BusinessOwnerProfile();
        _db.Setup(d => d.Ratings).Returns(TestDbSet.From(
            RatingOf(first.Id, null, 5),
            RatingOf(second.Id, null, 2),
            RatingOf(second.Id, null, 4)));

        await _sut.RecalculateAsync([first, second]);

        (first.ServiceRatingSum, first.ServiceRatingCount).Should().Be((5m, 1));
        (second.ServiceRatingSum, second.ServiceRatingCount).Should().Be((6m, 2));
    }

    [Fact]
    public async Task RecalculateAndSave_SavesOnce()
    {
        var business = new BusinessOwnerProfile();
        _db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From(business));
        _db.Setup(d => d.Ratings).Returns(TestDbSet.From<Rating>());

        await _sut.RecalculateAndSaveAsync(business.Id);

        business.LevelRecalculatedAt.Should().Be(Now);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ServiceRating_IsRecountedFromItsOwnRatings()
    {
        var service = new BusinessService { RatingSum = 99m, RatingCount = 99 };
        var business = Guid.NewGuid();
        _db.Setup(d => d.BusinessServices).Returns(TestDbSet.From(service));
        _db.Setup(d => d.Ratings).Returns(TestDbSet.From(
            RatingOf(business, service.Id, 5),
            RatingOf(business, service.Id, 4),
            RatingOf(business, Guid.NewGuid(), 1)));

        await _sut.RecalculateServiceRatingAsync(service.Id);

        service.RatingSum.Should().Be(9m);
        service.RatingCount.Should().Be(2);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ServiceRating_ForAMissingService_DoesNothing()
    {
        _db.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());

        await _sut.RecalculateServiceRatingAsync(Guid.NewGuid());

        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }
}
