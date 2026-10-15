using FluentValidation;

namespace Zuno.Application.Modules.HiringPost.Commands.RaiseAgreedSalary;

public class RaiseAgreedSalaryCommandValidator : AbstractValidator<RaiseAgreedSalaryCommand>
{
    public RaiseAgreedSalaryCommandValidator()
    {
        RuleFor(x => x.ApplicationId).NotEmpty();
        RuleFor(x => x.NewAmount)
            .GreaterThan(0).WithMessage("Salary must be greater than 0.")
            .LessThanOrEqualTo(99_999_999.99m);
        RuleFor(x => x.Reason).MaximumLength(300);
    }
}
