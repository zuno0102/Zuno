using FluentAssertions;
using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.CreateBooking;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.CreateBooking;

/// <summary>An order must be pinned inside the districts the business chose to work in.</summary>
public class CreateBookingCommandValidatorServiceAreaTests
{
    private static readonly District Kanyakumari = new()
    {
        Name = "Kanyakumari",
        CentreLatitude = 8.1833m,
        CentreLongitude = 77.4119m,
    };

    private static readonly District Thiruvananthapuram = new()
    {
        Name = "Thiruvananthapuram",
        CentreLatitude = 8.5241m,
        CentreLongitude = 76.9366m,
    };

    private static readonly District Tirunelveli = new()
    {
        Name = "Tirunelveli",
        CentreLatitude = 8.7139m,
        CentreLongitude = 77.7567m,
    };

    private static readonly District BengaluruUrban = new()
    {
        Name = "Bengaluru Urban",
        CentreLatitude = 12.9716m,
        CentreLongitude = 77.5946m,
    };

    private readonly Guid _serviceId = Guid.NewGuid();

    private CreateBookingCommandValidator Validator(params District[] served)
    {
        var dbContext = new Mock<IApplicationDbContext>();
        dbContext.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());
        dbContext.Setup(d => d.BusinessServiceVariants).Returns(TestDbSet.From<BusinessServiceVariant>());
        dbContext.Setup(d => d.BusinessServiceQuestions).Returns(TestDbSet.From<BusinessServiceQuestion>());
        dbContext.Setup(d => d.Districts)
            .Returns(TestDbSet.From(Kanyakumari, Thiruvananthapuram, Tirunelveli, BengaluruUrban));
        dbContext.Setup(d => d.BusinessServiceDistricts).Returns(TestDbSet.From(
            served.Select(d => new BusinessServiceDistrict
            {
                BusinessServiceId = _serviceId,
                DistrictId = d.Id,
                District = d,
            }).ToArray()));

        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));

        return new CreateBookingCommandValidator(dbContext.Object, clock.Object, new TestPlatformSettings());
    }

    private CreateBookingCommand Command(decimal latitude, decimal longitude) => new()
    {
        BusinessServiceId = _serviceId,
        ScheduledDate = new DateTimeOffset(2026, 2, 1, 10, 0, 0, TimeSpan.Zero),
        AddressLine1 = "12, Church Street",
        City = "Somewhere",
        State = "Somewhere",
        PostalCode = "600001",
        Latitude = latitude,
        Longitude = longitude,
    };

    [Fact]
    public async Task Refuses_A_Bengaluru_Pin_For_A_Kanyakumari_Only_Service()
    {
        var result = await Validator(Kanyakumari).TestValidateAsync(Command(12.9352m, 77.6245m));

        result.ShouldHaveValidationErrorFor(x => x.Latitude)
            .WithErrorMessage("Sorry, this service isn't available at your location yet. It's offered in Kanyakumari.");
    }

    [Fact]
    public async Task Accepts_A_Pin_In_Nagercoil()
    {
        var result = await Validator(Kanyakumari).TestValidateAsync(Command(8.1790m, 77.4340m));

        result.ShouldNotHaveValidationErrorFor(x => x.Latitude);
    }

    [Fact]
    public async Task Accepts_Marthandam_Though_It_Sits_Near_The_Kerala_Border()
    {
        var result = await Validator(Kanyakumari).TestValidateAsync(Command(8.3123m, 77.2201m));

        result.ShouldNotHaveValidationErrorFor(x => x.Latitude);
    }

    [Fact]
    public async Task Refuses_Central_Thiruvananthapuram_For_A_Kanyakumari_Only_Service()
    {
        var result = await Validator(Kanyakumari).TestValidateAsync(Command(8.5241m, 76.9366m));

        result.ShouldHaveValidationErrorFor(x => x.Latitude);
    }

    [Fact]
    public async Task Accepts_A_Pin_In_Any_Of_Several_Served_Districts()
    {
        var result = await Validator(Kanyakumari, BengaluruUrban).TestValidateAsync(Command(12.9352m, 77.6245m));

        result.ShouldNotHaveValidationErrorFor(x => x.Latitude);
    }

    [Fact]
    public async Task Does_Not_Refuse_When_A_Served_District_Has_No_Known_Centre()
    {
        var unmapped = new District { Name = "Somewhere North" };

        var result = await Validator(unmapped).TestValidateAsync(Command(12.9352m, 77.6245m));

        result.ShouldNotHaveValidationErrorFor(x => x.Latitude);
    }
}
