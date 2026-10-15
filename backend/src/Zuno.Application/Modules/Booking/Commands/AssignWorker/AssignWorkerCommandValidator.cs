using FluentValidation;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Booking.Commands.AssignWorker;

public class AssignWorkerCommandValidator : AbstractValidator<AssignWorkerCommand>
{
    public AssignWorkerCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.WorkerProfileId).NotEmpty();

        RuleFor(x => x.SalaryAmount)
            .GreaterThan(0)
            .When(x => x.SalaryAmount.HasValue)
            .WithMessage("Enter what this worker is paid, or leave it blank.");

        RuleFor(x => x.SalaryUnit)
            .Must(unit => Enum.TryParse<SalaryUnit>(unit, ignoreCase: true, out _))
            .When(x => !string.IsNullOrWhiteSpace(x.SalaryUnit))
            .WithMessage($"SalaryUnit must be one of: {string.Join(", ", Enum.GetNames<SalaryUnit>())}.");

        // The two halves travel together or not at all. An amount with no unit cannot be read —
        // ₹800 an hour and ₹800 for the whole event differ by a factor of eight on a long day —
        // and a unit with no amount says nothing. Refused rather than defaulted, because guessing
        // here reprices someone's wage silently.
        RuleFor(x => x.SalaryUnit)
            .NotEmpty()
            .When(x => x.SalaryAmount.HasValue)
            .WithMessage("Say what the amount is per: event, day or hour.");

        RuleFor(x => x.SalaryAmount)
            .NotNull()
            .When(x => !string.IsNullOrWhiteSpace(x.SalaryUnit))
            .WithMessage("Enter the amount this worker is paid.");
    }
}
