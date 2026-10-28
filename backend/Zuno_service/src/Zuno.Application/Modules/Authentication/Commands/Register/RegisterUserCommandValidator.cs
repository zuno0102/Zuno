using FluentValidation;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.Validators;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Authentication.Commands.Register;

public class RegisterUserCommandValidator : AbstractValidator<RegisterUserCommand>
{
    private static readonly string[] SelfRegistrableRoles =
    [
        nameof(UserRoleType.Customer),
        nameof(UserRoleType.BusinessOwner),
        nameof(UserRoleType.Worker),
    ];

    public RegisterUserCommandValidator(IUserRepository userRepository)
    {
        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.Email) || !string.IsNullOrWhiteSpace(x.PhoneNumber))
            .WithMessage("Either Email or PhoneNumber must be provided.");

        When(x => !string.IsNullOrWhiteSpace(x.Email), () =>
        {
            RuleFor(x => x.Email!)
                .EmailAddress().WithMessage("Email is not a valid email address.")
                .MustAsync(async (email, cancellationToken) =>
                    !await userRepository.ExistsByEmailAsync(email, cancellationToken))
                .WithMessage("An account with this email already exists.");
        });

        When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber), () =>
        {
            RuleFor(x => x.PhoneNumber!)
                .Matches(@"^[6-9]\d{9}$").WithMessage("PhoneNumber must be a valid 10-digit Indian mobile number.")
                .MustAsync(async (phoneNumber, cancellationToken) =>
                    !await userRepository.ExistsByPhoneNumberAsync(phoneNumber, cancellationToken))
                .WithMessage("An account with this phone number already exists.");
        });

        RuleFor(x => x.Password).MustBeAStrongPassword();

        RuleFor(x => x.FirstName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.LastName).NotEmpty().MaximumLength(100);

        RuleFor(x => x.Role)
            .NotEmpty()
            .Must(role => SelfRegistrableRoles.Contains(role, StringComparer.OrdinalIgnoreCase))
            .WithMessage($"Role must be one of: {string.Join(", ", SelfRegistrableRoles)}.");
    }
}
