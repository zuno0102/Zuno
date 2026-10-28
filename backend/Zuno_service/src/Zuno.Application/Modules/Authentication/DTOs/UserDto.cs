namespace Zuno.Application.Modules.Authentication.DTOs;

public class UserDto
{
    public Guid Id { get; set; }

    public string? Email { get; set; }

    public string? PhoneNumber { get; set; }

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string? ProfileImageUrl { get; set; }

    public string Role { get; set; } = string.Empty;

    public bool EmailConfirmed { get; set; }

    public bool PhoneNumberConfirmed { get; set; }
}
