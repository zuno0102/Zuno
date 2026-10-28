using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// What a business pays to list a vacancy, and for how long. Set by the app owner; each paid vacancy
/// keeps a copy of the amount it was charged, so changing a plan never rewrites past payments.
/// </summary>
public class VacancyFeePlan : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    /// <summary>How many days one payment keeps the vacancy listed.</summary>
    public int ListingDays { get; set; }

    public short SortOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
