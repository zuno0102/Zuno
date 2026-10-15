using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Commands.Register;

public class RegisterUserCommand : IRequest<AuthResponseDto>
{
    public string? Email { get; set; }

    public string? PhoneNumber { get; set; }

    public string Password { get; set; } = string.Empty;

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string Role { get; set; } = string.Empty;

    public string? IpAddress { get; set; }
}
