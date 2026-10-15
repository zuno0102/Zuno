using MediatR;

namespace Zuno.Application.Modules.Authentication.Commands.ForgotPassword;

public class ForgotPasswordCommand : IRequest
{
    public string Email { get; set; } = string.Empty;
}
