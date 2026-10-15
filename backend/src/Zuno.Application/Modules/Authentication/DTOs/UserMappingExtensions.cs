using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Authentication.DTOs;

public static class UserMappingExtensions
{
    public static UserDto ToDto(this User user) => new()
    {
        Id = user.Id,
        Email = user.Email,
        PhoneNumber = user.PhoneNumber,
        FirstName = user.FirstName,
        LastName = user.LastName,
        ProfileImageUrl = user.ProfileImageUrl,
        Role = user.Role.Name,
        EmailConfirmed = user.EmailConfirmed,
        PhoneNumberConfirmed = user.PhoneNumberConfirmed,
    };
}
