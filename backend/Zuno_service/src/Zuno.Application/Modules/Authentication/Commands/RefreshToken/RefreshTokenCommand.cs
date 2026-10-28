using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Commands.RefreshToken;

public class RefreshTokenCommand : IRequest<AuthResponseDto>
{
    public string RefreshToken { get; set; } = string.Empty;

    public string? IpAddress { get; set; }
}
