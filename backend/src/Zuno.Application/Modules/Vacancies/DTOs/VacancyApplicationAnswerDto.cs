using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>
/// One answer or document. A document carries no URL — it is fetched through the download endpoint,
/// which checks who is asking.
/// </summary>
public class VacancyApplicationAnswerDto
{
    public Guid Id { get; set; }

    public VacancyRequirementKind Kind { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public string? AnswerText { get; set; }

    public bool HasFile { get; set; }

    public string? FileName { get; set; }

    public string? ContentType { get; set; }

    public long? FileSizeBytes { get; set; }

    public short SortOrder { get; set; }
}
