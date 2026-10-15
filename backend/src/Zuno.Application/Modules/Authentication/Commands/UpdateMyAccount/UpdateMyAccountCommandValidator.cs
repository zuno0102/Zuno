using FluentValidation;

namespace Zuno.Application.Modules.Authentication.Commands.UpdateMyAccount;

public class UpdateMyAccountCommandValidator : AbstractValidator<UpdateMyAccountCommand>
{
    public UpdateMyAccountCommandValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty().WithMessage("Enter your first name.")
            .MaximumLength(100);

        RuleFor(x => x.LastName)
            .NotEmpty().WithMessage("Enter your last name.")
            .MaximumLength(100);

        // Indian mobile numbers: ten digits starting 6-9. Matches how numbers are validated at
        // registration, so an account cannot be edited into a shape it could not have been created in.
        RuleFor(x => x.PhoneNumber)
            .Matches(@"^[6-9]\d{9}$")
            .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber))
            .WithMessage("Enter a 10-digit mobile number.");
    }
}
