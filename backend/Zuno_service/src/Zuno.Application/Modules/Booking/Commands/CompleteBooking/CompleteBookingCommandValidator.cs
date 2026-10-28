using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.CompleteBooking;

public class CompleteBookingCommandValidator : AbstractValidator<CompleteBookingCommand>
{
    public CompleteBookingCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
    }
}
