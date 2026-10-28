using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// A kind of long-running job a vacancy can be — full-time, contract, internship. Reference data:
/// seeded, and managed by the app owner rather than by code.
/// </summary>
public class VacancyJobType : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Whether jobs of this kind run for a set length — a 1-month contract — so a vacancy of this type
    /// must say how many months.
    /// </summary>
    public bool HasFixedLength { get; set; }

    public short SortOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
