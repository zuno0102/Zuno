using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class User : BaseEntity
{
    public string? Email { get; set; }

    public string? PhoneNumber { get; set; }

    public string PasswordHash { get; set; } = string.Empty;

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string? ProfileImageUrl { get; set; }

    public Guid RoleId { get; set; }

    public Role Role { get; set; } = null!;

    public bool EmailConfirmed { get; set; }

    public bool PhoneNumberConfirmed { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTimeOffset? LastLoginDate { get; set; }

    public short FailedLoginAttempts { get; set; }

    public DateTimeOffset? LockoutEndDate { get; set; }

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();

    public ICollection<Address> Addresses { get; set; } = new List<Address>();

    public CustomerProfile? CustomerProfile { get; set; }

    public BusinessOwnerProfile? BusinessOwnerProfile { get; set; }

    public WorkerProfile? WorkerProfile { get; set; }

    public AdminProfile? AdminProfile { get; set; }

    public bool IsLockedOut => LockoutEndDate.HasValue && LockoutEndDate.Value > DateTimeOffset.UtcNow;
}
