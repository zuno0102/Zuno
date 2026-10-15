using MediatR;

namespace Zuno.Application.Modules.Authentication.Commands.RevokeToken;

public class RevokeTokenCommand : IRequest
{
    public string RefreshToken { get; set; } = string.Empty;

    public string? IpAddress { get; set; }
}
