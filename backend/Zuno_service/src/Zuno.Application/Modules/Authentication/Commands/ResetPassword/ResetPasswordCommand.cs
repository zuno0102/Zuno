using MediatR;

namespace Zuno.Application.Modules.Authentication.Commands.ResetPassword;

public class ResetPasswordCommand : IRequest
{
    public string Token { get; set; } = string.Empty;

    public string NewPassword { get; set; } = string.Empty;
}
