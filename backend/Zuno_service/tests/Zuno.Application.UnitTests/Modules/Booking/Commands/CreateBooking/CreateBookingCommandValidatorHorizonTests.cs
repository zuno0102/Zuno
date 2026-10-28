using FluentValidation.TestHelper;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Booking.Commands.CreateBooking;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Booking.Commands.CreateBooking;

/// <summary>How far ahead a customer may book follows the platform setting, on the server as in the app.</summary>
public class CreateBookingCommandValidatorHorizonTests
{
    private static readonly DateTimeOffset Now = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private static CreateBookingCommandValidator Validator(int maxDaysAhead)
    {
        var dbContext = new Mock<IApplicationDbContext>();
        dbContext.Setup(d => d.BusinessServices).Returns(TestDbSet.From<BusinessService>());
        dbContext.Setup(d => d.BusinessServiceVariants).Returns(TestDbSet.From<BusinessServiceVariant>());
        dbContext.Setup(d => d.BusinessServiceQuestions).Returns(TestDbSet.From<BusinessServiceQuestion>());
        dbContext.Setup(d => d.BusinessServiceDistricts).Returns(TestDbSet.From<BusinessServiceDistrict>());
        dbContext.Setup(d => d.Districts).Returns(TestDbSet.From<District>());

        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);

        return new CreateBookingCommandValidator(
            dbContext.Object,
            clock.Object,
            new TestPlatformSettings(PlatformRules.Defaults with { CustomerBookingMaxDaysAhead = maxDaysAhead }));
    }

    private static CreateBookingCommand On(DateTimeOffset when) => new()
    {
        BusinessServiceId = Guid.NewGuid(),
        ScheduledDate = when,
        AddressLine1 = "12, Church Street",
        City = "Marthandam",
        State = "Tamil Nadu",
        PostalCode = "629165",
        Latitude = 8.3123m,
        Longitude = 77.2201m,
    };

    [Theory]
    [InlineData(90, 90)]
    [InlineData(30, 29)]
    public async Task A_Date_Inside_The_Horizon_Is_Accepted(int maxDaysAhead, int daysAhead) =>
        (await Validator(maxDaysAhead).TestValidateAsync(On(Now.AddDays(daysAhead))))
            .ShouldNotHaveValidationErrorFor(x => x.ScheduledDate);

    [Theory]
    [InlineData(90, 91)]
    [InlineData(30, 31)]
    public async Task A_Date_Past_The_Horizon_Is_Refused(int maxDaysAhead, int daysAhead) =>
        (await Validator(maxDaysAhead).TestValidateAsync(On(Now.AddDays(daysAhead))))
            .ShouldHaveValidationErrorFor(x => x.ScheduledDate)
            .WithErrorMessage($"Bookings can be made up to {maxDaysAhead} days ahead.");
}
