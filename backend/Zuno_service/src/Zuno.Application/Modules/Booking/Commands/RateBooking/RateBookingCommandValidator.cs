using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.RateBooking;

public class RateBookingCommandValidator : AbstractValidator<RateBookingCommand>
{
    public RateBookingCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.Score).InclusiveBetween((short)1, (short)5);
        RuleFor(x => x.Comment).MaximumLength(1000);
    }
}
