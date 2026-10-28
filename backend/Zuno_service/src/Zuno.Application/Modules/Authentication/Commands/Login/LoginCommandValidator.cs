using FluentValidation;

namespace Zuno.Application.Modules.Authentication.Commands.Login;

public class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.EmailOrPhone).NotEmpty();
        RuleFor(x => x.Password).NotEmpty();
    }
}
