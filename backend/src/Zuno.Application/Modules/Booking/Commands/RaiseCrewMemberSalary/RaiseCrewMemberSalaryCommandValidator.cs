using FluentValidation;

namespace Zuno.Application.Modules.Booking.Commands.RaiseCrewMemberSalary;

public class RaiseCrewMemberSalaryCommandValidator : AbstractValidator<RaiseCrewMemberSalaryCommand>
{
    public RaiseCrewMemberSalaryCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.WorkerProfileId).NotEmpty();
        RuleFor(x => x.Increase)
            .GreaterThan(0).WithMessage("The raise must be more than ₹0.")
            .LessThanOrEqualTo(99_999_999.99m);
        RuleFor(x => x.Reason).MaximumLength(300);
    }
}
