using FluentAssertions;
using Zuno.Application.Common.Settings;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Commands.CreateHiringPost;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// A hiring post is placed on the map from the order it was raised for, or from what the business
/// picked — so the existing worker "nearby jobs" search can find it.
/// </summary>
public class HiringPostLocationTests
{
    private static readonly District Kanniyakumari = new()
    {
        Id = Guid.NewGuid(),
        Name = "Kanniyakumari",
        CentreLatitude = 8.1833m,
        CentreLongitude = 77.4119m,
    };

    private static readonly District Thiruvananthapuram = new()
    {
        Id = Guid.NewGuid(),
        Name = "Thiruvananthapuram",
        CentreLatitude = 8.5241m,
        CentreLongitude = 76.9366m,
    };

    private readonly Mock<IApplicationDbContext> _dbContext = new();

    public HiringPostLocationTests()
    {
        _dbContext.Setup(d => d.Districts).Returns(TestDbSet.From(Kanniyakumari, Thiruvananthapuram));
    }

    [Fact]
    public async Task Picks_The_District_Whose_Centre_Is_Nearest()
    {
        // Marthandam sits between the two centres but is closer to Kanniyakumari's.
        var id = await HiringPostLocation.NearestDistrictIdAsync(
            8.3123m, 77.2201m, PlatformRules.Defaults.DistrictMatchMaxDistanceKm, _dbContext.Object, CancellationToken.None);

        id.Should().Be(Kanniyakumari.Id);
    }

    [Fact]
    public async Task Leaves_The_District_Empty_Far_From_Any_Known_Centre()
    {
        // Delhi: nowhere near either seeded centre.
        var id = await HiringPostLocation.NearestDistrictIdAsync(
            28.6139m, 77.2090m, PlatformRules.Defaults.DistrictMatchMaxDistanceKm, _dbContext.Object, CancellationToken.None);

        id.Should().BeNull();
    }

    [Theory]
    [InlineData("Geocoded", HiringPostLocationPrecision.Geocoded)]
    [InlineData("geocoded", HiringPostLocationPrecision.Geocoded)]
    [InlineData("Pinned", HiringPostLocationPrecision.Pinned)]
    [InlineData(null, HiringPostLocationPrecision.Pinned)]
    [InlineData("DistrictApprox", HiringPostLocationPrecision.Pinned)]
    public void Only_Accepts_Pinned_Or_Geocoded_From_A_Client(string? value, HiringPostLocationPrecision expected)
    {
        HiringPostLocation.ParsePrecision(value).Should().Be(expected);
    }

    [Fact]
    public async Task A_Post_Raised_From_An_Order_Takes_The_Orders_Pin()
    {
        var (handler, booking, posts) = HandlerWithBooking(orderLatitude: 8.3123m, orderLongitude: 77.2201m);

        var result = await handler.Handle(new CreateHiringPostCommand
        {
            BookingId = booking.Id,
            Title = "Catering crew",
            EventDate = DateTimeOffset.UtcNow.AddDays(5),
            SalaryAmount = 900,
            // What the business typed is ignored for the point: the order's pin wins.
            Latitude = 10m,
            Longitude = 76m,
        }, CancellationToken.None);

        var post = posts.Single();
        post.Latitude.Should().Be(8.3123m);
        post.Longitude.Should().Be(77.2201m);
        post.LocationPrecision.Should().Be(HiringPostLocationPrecision.Pinned);
        post.DistrictId.Should().Be(Kanniyakumari.Id);
        post.Location.Should().Be("12, Church Street, Opposite Nila Nagar Church, Marthandam, Tamil Nadu");
        result.LocationPrecision.Should().Be("Pinned");
    }

    [Fact]
    public async Task A_Post_With_No_Order_Uses_The_Point_The_Business_Picked()
    {
        var (handler, _, posts) = HandlerWithBooking(orderLatitude: null, orderLongitude: null);

        await handler.Handle(new CreateHiringPostCommand
        {
            Title = "Stage helpers",
            EventDate = DateTimeOffset.UtcNow.AddDays(5),
            SalaryAmount = 700,
            Location = "Near St. Mary's Church, Kuzhithurai",
            Latitude = 8.3170m,
            Longitude = 77.1950m,
            LocationPrecision = "Geocoded",
        }, CancellationToken.None);

        var post = posts.Single();
        post.Latitude.Should().Be(8.3170m);
        post.LocationPrecision.Should().Be(HiringPostLocationPrecision.Geocoded);
        post.DistrictId.Should().Be(Kanniyakumari.Id);
        post.Location.Should().Be("Near St. Mary's Church, Kuzhithurai");
    }

    [Fact]
    public async Task A_Post_With_No_Point_Stays_Unplaced()
    {
        var (handler, _, posts) = HandlerWithBooking(orderLatitude: null, orderLongitude: null);

        await handler.Handle(new CreateHiringPostCommand
        {
            Title = "Helpers",
            EventDate = DateTimeOffset.UtcNow.AddDays(5),
            SalaryAmount = 500,
        }, CancellationToken.None);

        var post = posts.Single();
        post.HasPosition.Should().BeFalse();
        post.LocationPrecision.Should().Be(HiringPostLocationPrecision.None);
    }

    private (CreateHiringPostCommandHandler Handler, Domain.Entities.Booking Booking, List<Domain.Entities.HiringPost> Posts)
        HandlerWithBooking(decimal? orderLatitude, decimal? orderLongitude)
    {
        var userId = Guid.NewGuid();
        var business = new BusinessOwnerProfile { Id = Guid.NewGuid(), UserId = userId, BusinessName = "Shajil Caterers" };

        var booking = new Domain.Entities.Booking
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = business.Id,
            BookingStatus = BookingStatus.Confirmed,
            BusinessService = new BusinessService { Name = "Wedding catering", Media = [] },
            Address = new Address
            {
                Line1 = "12, Church Street",
                Line2 = "Opposite Nila Nagar Church",
                City = "Marthandam",
                State = "Tamil Nadu",
                PostalCode = "629165",
                Latitude = orderLatitude,
                Longitude = orderLongitude,
            },
        };

        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(userId);

        var businesses = new Mock<IBusinessOwnerProfileRepository>();
        businesses.Setup(r => r.GetByUserIdAsync(userId, It.IsAny<CancellationToken>())).ReturnsAsync(business);

        var posts = new List<Domain.Entities.HiringPost>();
        var postSet = new Mock<Microsoft.EntityFrameworkCore.DbSet<Domain.Entities.HiringPost>>();
        postSet.Setup(s => s.Add(It.IsAny<Domain.Entities.HiringPost>()))
            .Callback<Domain.Entities.HiringPost>(posts.Add);

        _dbContext.Setup(d => d.Bookings).Returns(TestDbSet.From(booking));
        _dbContext.Setup(d => d.HiringPosts).Returns(postSet.Object);
        _dbContext.Setup(d => d.ServiceSubCategories).Returns(TestDbSet.From<ServiceSubCategory>());

        return (new CreateHiringPostCommandHandler(currentUser.Object, businesses.Object, new TestPlatformSettings(), _dbContext.Object), booking, posts);
    }
}
