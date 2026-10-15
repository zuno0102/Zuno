using FluentValidation;

namespace Zuno.Application.Modules.Worker.Commands.UpdateMyWorkerProfile;

/// <summary>
/// Checks each field only when it was sent, since null means "leave it alone".
/// </summary>
/// <remarks>
/// The phone rules are deliberately identical to registration's
/// (<c>RegisterUserCommandValidator</c>): a number that would have been refused at sign-up must not
/// be accepted through the back door of an edit form, or the unique index on <c>phone_number</c>
/// turns a typo into a 500.
/// </remarks>
public class UpdateMyWorkerProfileCommandValidator : AbstractValidator<UpdateMyWorkerProfileCommand>
{
    public UpdateMyWorkerProfileCommandValidator()
    {
        // Same rules as the account edit every other role uses, so a name that would be refused
        // there cannot be set here instead.
        When(x => x.FirstName is not null, () =>
        {
            RuleFor(x => x.FirstName!)
                .NotEmpty().WithMessage("Enter your first name.")
                .MaximumLength(100);
        });

        When(x => x.LastName is not null, () =>
        {
            RuleFor(x => x.LastName!)
                .NotEmpty().WithMessage("Enter your last name.")
                .MaximumLength(100);
        });

        When(x => x.PhoneNumber is not null, () =>
        {
            RuleFor(x => x.PhoneNumber!)
                .Matches(@"^[6-9]\d{9}$")
                .WithMessage("Enter a valid 10-digit Indian mobile number.");
        });

        When(x => x.UpiVpa is not null, () =>
        {
            RuleFor(x => x.UpiVpa!)
                .NotEmpty().WithMessage("Enter your UPI address, or leave the field untouched.")
                .MaximumLength(100)
                // name@handle. Loose on purpose: banks keep adding handles, and a strict list would
                // start refusing valid addresses the month after it was written. The payout provider
                // is the real authority and rejects a bad one at verification.
                .Matches(@"^[\w.\-]{2,}@[A-Za-z]{2,}$")
                .WithMessage("A UPI address looks like name@bank, for example ravi@okhdfcbank.");
        });

        When(x => x.HourlyRate is not null, () =>
        {
            RuleFor(x => x.HourlyRate!.Value)
                .GreaterThan(0).WithMessage("An hourly rate has to be more than zero.")
                .LessThanOrEqualTo(100000).WithMessage("That hourly rate looks like a mistake.");
        });

        When(x => x.ExperienceYears is not null, () =>
        {
            RuleFor(x => x.ExperienceYears!.Value)
                .GreaterThanOrEqualTo((short)0)
                .WithMessage("Years of experience cannot be negative.")
                .LessThanOrEqualTo((short)70)
                .WithMessage("That many years of experience looks like a mistake.");
        });
    }
}
