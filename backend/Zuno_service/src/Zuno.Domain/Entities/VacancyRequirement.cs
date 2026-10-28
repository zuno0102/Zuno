using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// A custom field the business adds to its application form — "Aadhaar" as a file, "Do you have a
/// two-wheeler?" as Yes/No. The business names its own, because no fixed form fits a shop and an
/// office alike.
/// </summary>
public class VacancyRequirement : BaseEntity
{
    public Guid VacancyId { get; set; }

    public Vacancy Vacancy { get; set; } = null!;

    public VacancyRequirementKind Kind { get; set; }

    /// <summary>The field's label, in the business's own words.</summary>
    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }

    public short SortOrder { get; set; }
}
