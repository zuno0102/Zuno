using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>One custom field on a vacancy's application form.</summary>
public class VacancyRequirementDto
{
    public Guid Id { get; set; }

    public VacancyRequirementKind Kind { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }

    public short SortOrder { get; set; }
}
