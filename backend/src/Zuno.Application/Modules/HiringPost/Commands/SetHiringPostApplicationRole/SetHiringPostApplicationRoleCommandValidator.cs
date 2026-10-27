using FluentValidation;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.HiringPost.Commands.SetHiringPostApplicationRole;

public class SetHiringPostApplicationRoleCommandValidator : AbstractValidator<SetHiringPostApplicationRoleCommand>
{
    public SetHiringPostApplicationRoleCommandValidator()
    {
        RuleFor(x => x.ApplicationId).NotEmpty();

        // One of the three, or blank to take the role away — the same list an order's crew uses.
        RuleFor(x => x.Role)
            .Must(role => string.IsNullOrWhiteSpace(role) || JobRole.IsKnown(role))
            .WithMessage($"Role must be one of: {string.Join(", ", JobRole.All)}.");
    }
}
