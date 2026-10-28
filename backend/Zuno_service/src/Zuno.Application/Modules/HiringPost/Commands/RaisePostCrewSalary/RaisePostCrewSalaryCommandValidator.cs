using FluentValidation;
using Zuno.Domain.Common;

namespace Zuno.Application.Modules.HiringPost.Commands.RaisePostCrewSalary;

public class RaisePostCrewSalaryCommandValidator : AbstractValidator<RaisePostCrewSalaryCommand>
{
    public RaisePostCrewSalaryCommandValidator()
    {
        RuleFor(x => x.HiringPostId).NotEmpty();
        RuleFor(x => x.Increase)
            .GreaterThan(0).WithMessage("The raise must be more than ₹0.")
            .LessThanOrEqualTo(MoneyLimits.MaxAmount);
        RuleFor(x => x.Reason).MaximumLength(300);
    }
}
