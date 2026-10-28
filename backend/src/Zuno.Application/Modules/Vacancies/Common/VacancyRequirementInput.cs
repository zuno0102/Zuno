using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>One custom field on the vacancy form.</summary>
public class VacancyRequirementInput
{
    public VacancyRequirementKind Kind { get; set; }

    /// <summary>The field's label — "Aadhaar", "Do you have a two-wheeler?".</summary>
    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }
}
