using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.Location;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Customer;

/// <summary>
/// The customer's location is kept in their account: read from the phone, picked by hand, or cleared
/// to everywhere — and how it was set decides whether the app may change it by itself next time.
/// </summary>
public class CustomerLocationTests
{
    private static readonly State Kerala = new() { Id = Guid.NewGuid(), Name = "Kerala" };
    private static readonly District Ernakulam = new() { Id = Guid.NewGuid(), Name = "Ernakulam", StateId = Kerala.Id, State = Kerala };

    private readonly Guid _userId = Guid.NewGuid();
    private readonly CustomerProfile _profile;
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly DateTimeOffset _now = new(2026, 11, 11, 9, 0, 0, TimeSpan.Zero);

    public CustomerLocationTests()
    {
        _profile = new CustomerProfile { UserId = _userId };
        _db.Setup(d => d.CustomerProfiles).Returns(TestDbSet.From(_profile));
        _db.Setup(d => d.Districts).Returns(TestDbSet.From(Ernakulam));
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);
    }

    private CustomerLocationHandlers Handlers(Guid? userId = null)
    {
        var user = new Mock<ICurrentUserService>();
        user.Setup(u => u.UserId).Returns(userId ?? _userId);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(_now);
        return new CustomerLocationHandlers(_db.Object, user.Object, clock.Object);
    }

    [Fact]
    public async Task A_new_customer_has_no_location()
    {
        var location = await Handlers().Handle(new GetMyCustomerLocationQuery(), default);

        location.DistrictId.Should().BeNull();
        location.Source.Should().BeNull();
    }

    [Fact]
    public async Task The_phone_location_is_saved_with_its_district_and_how_it_was_set()
    {
        var saved = await Handlers().Handle(new SetMyCustomerLocationCommand(Ernakulam.Id, CustomerLocationSources.Gps), default);

        saved.Should().Be(new CustomerLocationDto(Ernakulam.Id, "Ernakulam", Kerala.Id, "Kerala", "Gps", _now));
        _profile.LocationDistrictId.Should().Be(Ernakulam.Id);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
        (await Handlers().Handle(new GetMyCustomerLocationQuery(), default)).DistrictName.Should().Be("Ernakulam");
    }

    [Fact]
    public async Task Clearing_keeps_that_it_was_cleared_so_the_app_does_not_set_it_again()
    {
        await Handlers().Handle(new SetMyCustomerLocationCommand(Ernakulam.Id, CustomerLocationSources.Manual), default);

        var cleared = await Handlers().Handle(new SetMyCustomerLocationCommand(null, CustomerLocationSources.Cleared), default);

        cleared.DistrictId.Should().BeNull();
        cleared.Source.Should().Be("Cleared");
        _profile.LocationDistrictId.Should().BeNull();
    }

    [Fact]
    public async Task An_unknown_district_is_refused()
    {
        var act = () => Handlers().Handle(new SetMyCustomerLocationCommand(Guid.NewGuid(), CustomerLocationSources.Gps), default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        _profile.LocationDistrictId.Should().BeNull();
    }

    [Fact]
    public async Task Another_users_profile_is_never_reached()
    {
        var act = () => Handlers(Guid.NewGuid()).Handle(new SetMyCustomerLocationCommand(Ernakulam.Id, CustomerLocationSources.Gps), default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        _profile.LocationDistrictId.Should().BeNull();
    }

    [Theory]
    [InlineData(true, "Gps", true)]
    [InlineData(true, "Manual", true)]
    [InlineData(false, "Cleared", true)]
    [InlineData(false, "Gps", false)]
    [InlineData(true, "Cleared", false)]
    [InlineData(true, "Satellite", false)]
    public void Only_a_sensible_location_is_accepted(bool withDistrict, string source, bool valid)
    {
        new SetMyCustomerLocationCommandValidator()
            .Validate(new SetMyCustomerLocationCommand(withDistrict ? Guid.NewGuid() : null, source))
            .IsValid.Should().Be(valid);
    }
}
