namespace Zuno.Application.Modules.Authentication.DTOs;

public class AuthResponseDto
{
    public string AccessToken { get; set; } = string.Empty;

    public string RefreshToken { get; set; } = string.Empty;

    public DateTimeOffset AccessTokenExpiresAt { get; set; }

    public UserDto User { get; set; } = null!;
}
