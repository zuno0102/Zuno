using FluentValidation;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.Commands.SetAssignmentRole;

public class SetAssignmentRoleCommandValidator : AbstractValidator<SetAssignmentRoleCommand>
{
    public SetAssignmentRoleCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.WorkerProfileId).NotEmpty();

        // One of the three, or blank to take the role away.
        //
        // Not free text. Anything typed would be a trade — "Painter", "Chef" — which describes the
        // person rather than what they are doing on this order, and only one specific value grants
        // anything. A field that accepts "Leed" and silently grants nothing is worse than a field
        // that refuses it.
        RuleFor(x => x.Role)
            .Must(role => string.IsNullOrWhiteSpace(role) || JobRole.IsKnown(role))
            .WithMessage($"Role must be one of: {string.Join(", ", JobRole.All)}.");
    }
}
