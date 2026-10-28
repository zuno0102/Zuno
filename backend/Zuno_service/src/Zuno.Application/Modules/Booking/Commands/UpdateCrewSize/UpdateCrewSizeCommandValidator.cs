using FluentValidation;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;

public class UpdateCrewSizeCommandValidator : AbstractValidator<UpdateCrewSizeCommand>
{
    public UpdateCrewSizeCommandValidator(IPlatformSettings platformSettings)
    {
        RuleFor(x => x.BookingId).NotEmpty();
        // The ceiling is a platform setting: an order's crew had no upper bound at all.
        RuleFor(x => x.RequiredWorkerCount)
            .Must(count => count >= 1 && count <= platformSettings.Current.OrderMaxCrewSize)
            .WithMessage(_ => $"Crew size must be between 1 and {platformSettings.Current.OrderMaxCrewSize}.");
    }
}
