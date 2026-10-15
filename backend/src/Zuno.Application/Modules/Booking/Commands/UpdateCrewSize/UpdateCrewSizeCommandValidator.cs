using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;

public class UpdateCrewSizeCommandValidator : AbstractValidator<UpdateCrewSizeCommand>
{
    public UpdateCrewSizeCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.RequiredWorkerCount).GreaterThanOrEqualTo(1);
    }
}
