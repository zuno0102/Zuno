using MediatR;

namespace Zuno.Application.Modules.Authentication.Commands.ChangePassword;

public class ChangePasswordCommand : IRequest
{
    public string CurrentPassword { get; set; } = string.Empty;

    public string NewPassword { get; set; } = string.Empty;
}
