using FluentValidation;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerForDate;

public class InviteWorkerForDateCommandValidator : AbstractValidator<InviteWorkerForDateCommand>
{
    public InviteWorkerForDateCommandValidator(IPlatformSettings platformSettings)
    {
        RuleFor(x => x.WorkerIdentifier).NotEmpty().MaximumLength(256);

        RuleFor(x => x.EventDate).NotEmpty();

        RuleFor(x => x.Title).MaximumLength(200);

        // Matches the column the post stores it in.
        RuleFor(x => x.Location).MaximumLength(300);

        RuleFor(x => x.DurationMinutes).ValidDuration(platformSettings);

        // Same floor a hiring post has. The figure is what the worker decides on and what the
        // payout is later drawn against, so there is no sensible zero.
        RuleFor(x => x.SalaryAmount).ValidWage();

        RuleFor(x => x.SalaryUnit).IsInEnum();
    }
}
