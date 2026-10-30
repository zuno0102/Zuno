namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// Read-only copy of the app's states, with the same ids the Service module uses, so a district
/// picked in the app means the same place in both.
/// </summary>
public class RefState
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;
}

/// <summary>Read-only copy of the app's districts — same ids as the Service module.</summary>
public class RefDistrict
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public RefState State { get; set; } = null!;
}
