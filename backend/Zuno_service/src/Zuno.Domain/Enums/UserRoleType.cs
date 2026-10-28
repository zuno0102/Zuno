namespace Zuno.Domain.Enums;

/// <summary>
/// Well-known role names. The Roles table (seeded from these values) is the actual FK source of truth
/// for Users.RoleId — this enum exists only so code can reference role names without magic strings.
/// </summary>
public enum UserRoleType
{
    Customer = 1,
    BusinessOwner = 2,
    Worker = 3,
    SuperAdmin = 4,
}
