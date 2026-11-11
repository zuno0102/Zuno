using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.Queries.GetNearestDistrict;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Catalog;

/// <summary>
/// The customer app turns the phone's location into a district with this, then narrows Service and
/// Rent listings to it. Nearest headquarters wins; too far from every one means no district.
/// </summary>
public class GetNearestDistrictTests
{
    private static readonly State Kerala = new() { Id = Guid.NewGuid(), Name = "Kerala" };
    private static readonly State TamilNadu = new() { Id = Guid.NewGuid(), Name = "Tamil Nadu" };

    // Headquarters points, roughly where they are.
    private static readonly District Ernakulam = District("Ernakulam", Kerala, 9.9816m, 76.2999m);
    private static readonly District Thiruvananthapuram = District("Thiruvananthapuram", Kerala, 8.5241m, 76.9366m);
    private static readonly District Kanyakumari = District("Kanyakumari", TamilNadu, 8.1833m, 77.4119m);
    private static readonly District NoCentre = new() { Id = Guid.NewGuid(), Name = "Unmapped", StateId = Kerala.Id, State = Kerala };

    private static District District(string name, State state, decimal lat, decimal lon) => new()
    {
        Id = Guid.NewGuid(),
        Name = name,
        StateId = state.Id,
        State = state,
        CentreLatitude = lat,
        CentreLongitude = lon,
    };

    private static Task<NearestDistrictDto?> Ask(decimal lat, decimal lon)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.Districts).Returns(TestDbSet.From(Ernakulam, Thiruvananthapuram, Kanyakumari, NoCentre));
        return new GetNearestDistrictQueryHandler(db.Object, new TestPlatformSettings())
            .Handle(new GetNearestDistrictQuery(lat, lon), default);
    }

    [Fact]
    public async Task Kakkanad_is_in_Ernakulam()
    {
        var district = await Ask(10.0159m, 76.3419m);

        district.Should().NotBeNull();
        district!.DistrictId.Should().Be(Ernakulam.Id);
        district.DistrictName.Should().Be("Ernakulam");
        district.StateId.Should().Be(Kerala.Id);
        district.StateName.Should().Be("Kerala");
        district.DistanceKm.Should().BeLessThan(10);
    }

    [Fact]
    public async Task Nagercoil_is_in_Kanyakumari_not_the_nearby_Kerala_capital()
    {
        (await Ask(8.1780m, 77.4344m))!.DistrictName.Should().Be("Kanyakumari");
    }

    [Fact]
    public async Task Far_from_every_headquarters_gets_no_district()
    {
        // Delhi: well past the 150 km service-area limit from every point here.
        (await Ask(28.6139m, 77.2090m)).Should().BeNull();
    }

    [Fact]
    public void The_limit_follows_the_platform_setting()
    {
        var centres = new List<GetNearestDistrictQueryHandler.Centre>
        {
            new(Ernakulam.Id, "Ernakulam", Kerala.Id, "Kerala", 9.9816, 76.2999),
        };

        // Thrissur town is about 70 km from Ernakulam's point.
        GetNearestDistrictQueryHandler.Nearest(10.5276, 76.2144, centres, 150).Should().NotBeNull();
        GetNearestDistrictQueryHandler.Nearest(10.5276, 76.2144, centres, 50).Should().BeNull();
        GetNearestDistrictQueryHandler.Nearest(10.5276, 76.2144, [], 150).Should().BeNull();
    }

    [Theory]
    [InlineData(91, 76, false)]
    [InlineData(-91, 76, false)]
    [InlineData(10, 181, false)]
    [InlineData(10, -181, false)]
    [InlineData(10, 76, true)]
    public void Only_a_real_point_is_asked(decimal lat, decimal lon, bool valid)
    {
        new GetNearestDistrictQueryValidator().Validate(new GetNearestDistrictQuery(lat, lon)).IsValid.Should().Be(valid);
    }
}
