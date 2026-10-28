using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Commands.Login;

public class LoginCommand : IRequest<AuthResponseDto>
{
    public string EmailOrPhone { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string? IpAddress { get; set; }
}
