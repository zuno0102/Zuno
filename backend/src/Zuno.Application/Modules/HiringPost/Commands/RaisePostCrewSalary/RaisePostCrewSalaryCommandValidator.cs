using FluentValidation;

namespace Zuno.Application.Modules.HiringPost.Commands.RaisePostCrewSalary;

public class RaisePostCrewSalaryCommandValidator : AbstractValidator<RaisePostCrewSalaryCommand>
{
    public RaisePostCrewSalaryCommandValidator()
    {
        RuleFor(x => x.HiringPostId).NotEmpty();
        RuleFor(x => x.Increase)
            .GreaterThan(0).WithMessage("The raise must be more than ₹0.")
            .LessThanOrEqualTo(99_999_999.99m);
        RuleFor(x => x.Reason).MaximumLength(300);
    }
}
