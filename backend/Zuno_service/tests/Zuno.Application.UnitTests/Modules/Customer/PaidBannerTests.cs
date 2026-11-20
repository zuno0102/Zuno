using FluentAssertions;
using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Admin.Commands.SetServiceBanner;
using Zuno.Application.Modules.Customer.Queries.GetDailyBanners;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Customer;

/// <summary>
/// The customers' top banner is sold: a service is in it only while its paid banner runs, and a
/// Super Admin records the payment.
/// </summary>
public class PaidBannerTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 20, 9, 0, 0, TimeSpan.Zero);

    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IDateTimeProvider> _clock = new();

    public PaidBannerTests()
    {
        _clock.Setup(c => c.UtcNow).Returns(Now);
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
    }

    private static BusinessService Service(string name, DateTimeOffset? paidUntil)
    {
        var business = new BusinessOwnerProfile
        {
            Id = Guid.NewGuid(),
            BusinessName = $"{name} shop",
            VerificationStatus = VerificationStatus.Verified,
            BusinessAddress = new Address { City = "Nagercoil" },
        };
        var service = new BusinessService
        {
            Id = Guid.NewGuid(),
            Name = name,
            Price = 500,
            BusinessOwnerProfile = business,
            BusinessOwnerProfileId = business.Id,
            ServiceCategory = new ServiceCategory { Name = "Cleaning" },
            BannerPaidUntil = paidUntil,
        };
        service.Media.Add(new BusinessServiceMedia { Url = $"/uploads/{name}.jpg" });
        return service;
    }

    private Task<List<Application.Modules.Customer.DTOs.ServiceListingDto>> BannersAsync(params BusinessService[] services)
    {
        _db.Setup(d => d.BusinessServices).Returns(TestDbSet.From(services));
        var settings = new Mock<IPlatformSettings>();
        settings.Setup(s => s.Current).Returns(PlatformRules.From(new Dictionary<string, string>()));
        return new GetDailyBannersQueryHandler(_db.Object, _clock.Object, settings.Object)
            .Handle(new GetDailyBannersQuery(), default);
    }

    [Fact]
    public async Task Only_a_service_with_a_running_paid_banner_is_in_the_banner()
    {
        var paid = Service("Paid", Now.AddDays(7));
        var ended = Service("Ended", Now.AddMinutes(-1));
        var free = Service("Free", null);

        var banners = await BannersAsync(paid, ended, free);

        banners.Select(b => b.Id).Should().Equal(paid.Id);
    }

    [Fact]
    public async Task With_no_paid_banner_there_is_no_banner()
    {
        var banners = await BannersAsync(Service("Free", null), Service("Ended", Now.AddDays(-3)));

        banners.Should().BeEmpty("the app then leaves the banner out");
    }

    [Fact]
    public async Task An_admin_records_a_paid_banner_and_can_end_it()
    {
        var service = Service("Cleaning", null);
        _db.Setup(d => d.BusinessServices).Returns(TestDbSet.From(service));
        var handler = new SetServiceBannerCommandHandler(_db.Object);

        var set = await handler.Handle(new SetServiceBannerCommand(service.Id, Now.AddDays(30)), default);
        set.BannerPaidUntil.Should().Be(Now.AddDays(30));
        service.BannerPaidUntil.Should().Be(Now.AddDays(30));

        await handler.Handle(new SetServiceBannerCommand(service.Id, null), default);
        service.BannerPaidUntil.Should().BeNull();
    }

    [Fact]
    public async Task An_unknown_service_is_not_found()
    {
        _db.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());

        var act = () => new SetServiceBannerCommandHandler(_db.Object)
            .Handle(new SetServiceBannerCommand(Guid.NewGuid(), Now.AddDays(1)), default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Fact]
    public void A_paid_until_in_the_past_or_over_a_year_ahead_is_refused()
    {
        var validator = new SetServiceBannerCommandValidator(_clock.Object);
        var id = Guid.NewGuid();

        validator.TestValidate(new SetServiceBannerCommand(id, Now.AddDays(-1))).ShouldHaveValidationErrorFor(x => x.PaidUntil);
        validator.TestValidate(new SetServiceBannerCommand(id, Now.AddDays(400))).ShouldHaveValidationErrorFor(x => x.PaidUntil);
        validator.TestValidate(new SetServiceBannerCommand(id, Now.AddDays(30))).ShouldNotHaveAnyValidationErrors();
        validator.TestValidate(new SetServiceBannerCommand(id, null)).ShouldNotHaveAnyValidationErrors();
    }
}
