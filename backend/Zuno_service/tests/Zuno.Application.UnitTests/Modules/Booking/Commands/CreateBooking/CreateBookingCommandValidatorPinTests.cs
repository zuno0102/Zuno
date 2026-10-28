using FluentAssertions;
using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Commands.CreateBooking;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.CreateBooking;

/// <summary>The job location must be pinned on a map, not only typed.</summary>
public class CreateBookingCommandValidatorPinTests
{
    private readonly CreateBookingCommandValidator _sut;

    public CreateBookingCommandValidatorPinTests()
    {
        var dbContext = new Mock<IApplicationDbContext>();
        dbContext.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());
        dbContext.Setup(d => d.BusinessServiceVariants).Returns(TestDbSet.From<BusinessServiceVariant>());
        dbContext.Setup(d => d.BusinessServiceQuestions).Returns(TestDbSet.From<BusinessServiceQuestion>());
        dbContext.Setup(d => d.BusinessServiceDistricts).Returns(TestDbSet.From<BusinessServiceDistrict>());
        dbContext.Setup(d => d.Districts).Returns(TestDbSet.From<District>());

        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));

        _sut = new CreateBookingCommandValidator(dbContext.Object, clock.Object, new TestPlatformSettings());
    }

    private static CreateBookingCommand Command(decimal? latitude, decimal? longitude) => new()
    {
        BusinessServiceId = Guid.NewGuid(),
        ScheduledDate = new DateTimeOffset(2026, 2, 1, 10, 0, 0, TimeSpan.Zero),
        AddressLine1 = "12, Church Street",
        City = "Marthandam",
        State = "Tamil Nadu",
        PostalCode = "629165",
        Latitude = latitude,
        Longitude = longitude,
    };

    [Fact]
    public async Task Accepts_A_Pinned_Location()
    {
        var result = await _sut.TestValidateAsync(Command(8.3123m, 77.2201m));

        result.ShouldNotHaveValidationErrorFor(x => x.Latitude);
        result.ShouldNotHaveValidationErrorFor(x => x.Longitude);
    }

    [Fact]
    public async Task Rejects_A_Booking_With_No_Pin()
    {
        var result = await _sut.TestValidateAsync(Command(null, null));

        result.ShouldHaveValidationErrorFor(x => x.Latitude)
            .WithErrorMessage("Pin the job location on the map.");
        result.ShouldHaveValidationErrorFor(x => x.Longitude);
    }

    [Theory]
    [InlineData(91, 77)]
    [InlineData(8, 181)]
    [InlineData(-91, -181)]
    public async Task Rejects_Coordinates_Outside_The_Globe(double latitude, double longitude)
    {
        var result = await _sut.TestValidateAsync(Command((decimal)latitude, (decimal)longitude));

        (result.Errors.Any(e => e.PropertyName is "Latitude" or "Longitude")).Should().BeTrue();
    }
}
