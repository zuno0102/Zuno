using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>One applicant, as the business reviewing them sees it.</summary>
public class VacancyApplicationDto
{
    public Guid Id { get; set; }

    public Guid VacancyId { get; set; }

    /// <summary>Which job this is for — needed where applicants from every job are listed together.</summary>
    public string VacancyTitle { get; set; } = string.Empty;

    public Guid WorkerProfileId { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    /// <summary>Shared because the worker applied: calling them is how the business takes it forward.</summary>
    public string? WorkerPhone { get; set; }

    public string? WorkerPhotoUrl { get; set; }

    public short? ExperienceYears { get; set; }

    public VacancyApplicationStatus Status { get; set; }

    public DateTimeOffset AppliedAt { get; set; }

    public DateTimeOffset? StatusChangedAt { get; set; }

    public string? BusinessNote { get; set; }

    public List<VacancyApplicationAnswerDto> Answers { get; set; } = [];
}
