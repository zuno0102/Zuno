using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.RaiseOrderCrewSalary;

public class RaiseOrderCrewSalaryCommandValidator : AbstractValidator<RaiseOrderCrewSalaryCommand>
{
    public RaiseOrderCrewSalaryCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.Increase)
            .GreaterThan(0).WithMessage("The raise must be more than ₹0.")
            .LessThanOrEqualTo(99_999_999.99m);
        RuleFor(x => x.Reason).MaximumLength(300);
    }
}
