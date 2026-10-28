using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Commands.ConfirmVacancyPayment;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

/// <summary>
/// The app says it paid; only a signature made with the server's secret proves it. A vacancy goes
/// live on proof, once, and only for the business that owns it.
/// </summary>
public class ConfirmVacancyPaymentTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);
    private static readonly Guid UserId = Guid.NewGuid();

    private readonly BusinessOwnerProfile _business = new() { Id = Guid.NewGuid(), UserId = UserId, BusinessName = "Shop" };
    private readonly Mock<IPayoutProvider> _provider = new();
    private readonly Mock<IApplicationDbContext> _db = new();

    private Vacancy Pending(string? orderId, Guid? ownerId = null)
    {
        var vacancy = new Vacancy
        {
            Id = Guid.NewGuid(),
            Title = "Receptionist",
            BusinessOwnerProfileId = ownerId ?? _business.Id,
            BusinessOwnerProfile = _business,
            VacancyJobType = new VacancyJobType { Name = "Full-time" },
        };
        vacancy.PriceWith(new VacancyFeePlan { Id = Guid.NewGuid(), Name = "Standard", Amount = 49m, ListingDays = 30 });
        vacancy.PendingOrderId = orderId;

        _db.Setup(d => d.Vacancies).Returns(TestDbSet.From(vacancy));
        _db.Setup(d => d.BusinessOwnerProfiles).Returns(TestDbSet.From(_business));
        return vacancy;
    }

    private Task<Zuno.Application.Modules.Vacancies.DTOs.VacancyDto> Confirm(
        Vacancy vacancy, string? paymentId, string? signature, bool simulate = false)
    {
        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(UserId);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);

        var handler = new ConfirmVacancyPaymentCommandHandler(
            currentUser.Object,
            clock.Object,
            _provider.Object,
            Options.Create(new RazorpaySettings { SimulateCollection = simulate }),
            _db.Object);

        return handler.Handle(
            new ConfirmVacancyPaymentCommand { VacancyId = vacancy.Id, ProviderPaymentId = paymentId, Signature = signature },
            CancellationToken.None);
    }

    [Fact]
    public async Task Handle_ValidSignature_GoesLive()
    {
        var vacancy = Pending("order_1");
        _provider.Setup(p => p.VerifyPaymentSignature("order_1", "pay_1", "sig")).Returns(true);

        var dto = await Confirm(vacancy, "pay_1", "sig");

        dto.IsLive.Should().BeTrue();
        vacancy.VacancyStatus.Should().Be(VacancyStatus.Open);
        vacancy.ExpiresAt.Should().Be(Now.AddDays(30));
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_ForgedSignature_IsRefusedAndNothingSaved()
    {
        var vacancy = Pending("order_1");
        _provider.Setup(p => p.VerifyPaymentSignature(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).Returns(false);

        var act = () => Confirm(vacancy, "pay_1", "forged");

        await act.Should().ThrowAsync<DomainException>();
        vacancy.VacancyStatus.Should().Be(VacancyStatus.AwaitingPayment);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Handle_SimulatedOrderOutsideSimulation_IsRefused()
    {
        var vacancy = Pending(string.Empty);

        var act = () => Confirm(vacancy, null, null, simulate: false);

        await act.Should().ThrowAsync<DomainException>("a leftover Development order must never go live for free");
        _provider.Verify(p => p.VerifyPaymentSignature(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Handle_SimulatedOrderWhileSimulating_GoesLive()
    {
        var vacancy = Pending(string.Empty);

        var dto = await Confirm(vacancy, null, null, simulate: true);

        dto.IsLive.Should().BeTrue();
    }

    [Fact]
    public async Task Handle_NothingPending_IsRefused()
    {
        var vacancy = Pending(null);

        var act = () => Confirm(vacancy, "pay_9", "sig");

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task Handle_SamePaymentTwice_ExtendsOnce()
    {
        var vacancy = Pending("order_1");
        _provider.Setup(p => p.VerifyPaymentSignature("order_1", "pay_1", "sig")).Returns(true);

        await Confirm(vacancy, "pay_1", "sig");
        await Confirm(vacancy, "pay_1", "sig");

        vacancy.PaidCount.Should().Be(1);
        vacancy.ExpiresAt.Should().Be(Now.AddDays(30));
    }

    [Fact]
    public async Task Handle_AnotherBusinessesVacancy_IsNotFound()
    {
        var vacancy = Pending("order_1", ownerId: Guid.NewGuid());
        _provider.Setup(p => p.VerifyPaymentSignature(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).Returns(true);

        var act = () => Confirm(vacancy, "pay_1", "sig");

        await act.Should().ThrowAsync<EntityNotFoundException>();
        vacancy.VacancyStatus.Should().Be(VacancyStatus.AwaitingPayment);
    }
}
