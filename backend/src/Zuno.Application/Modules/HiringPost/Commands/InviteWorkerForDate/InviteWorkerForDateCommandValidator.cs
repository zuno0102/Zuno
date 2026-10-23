using FluentValidation;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerForDate;

public class InviteWorkerForDateCommandValidator : AbstractValidator<InviteWorkerForDateCommand>
{
    public InviteWorkerForDateCommandValidator()
    {
        RuleFor(x => x.WorkerIdentifier).NotEmpty().MaximumLength(256);

        RuleFor(x => x.EventDate).NotEmpty();

        RuleFor(x => x.Title).MaximumLength(200);

        // Matches the column the post stores it in.
        RuleFor(x => x.Location).MaximumLength(300);

        RuleFor(x => x.DurationMinutes)
            .InclusiveBetween(
                Domain.Entities.HiringPost.MinDurationMinutes,
                Domain.Entities.HiringPost.MaxDurationMinutes);

        // Same floor a hiring post has. The figure is what the worker decides on and what the
        // payout is later drawn against, so there is no sensible zero.
        RuleFor(x => x.SalaryAmount)
            .GreaterThan(0).WithMessage("Pay must be greater than 0.")
            .LessThanOrEqualTo(99_999_999.99m);

        RuleFor(x => x.SalaryUnit).IsInEnum();
    }
}
