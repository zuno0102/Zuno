using FluentValidation;
using Zuno.Application.Modules.Authentication.Validators;

namespace Zuno.Application.Modules.Authentication.Commands.ResetPassword;

public class ResetPasswordCommandValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordCommandValidator()
    {
        RuleFor(x => x.Token).NotEmpty();
        RuleFor(x => x.NewPassword).MustBeAStrongPassword();
    }
}
