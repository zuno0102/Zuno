using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.RespondToAssignment;

public class RespondToAssignmentCommandValidator : AbstractValidator<RespondToAssignmentCommand>
{
    public RespondToAssignmentCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
    }
}
