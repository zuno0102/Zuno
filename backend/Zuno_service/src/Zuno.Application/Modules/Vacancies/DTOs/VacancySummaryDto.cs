namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>The business's full-time hiring at a glance, for its home screen.</summary>
public class VacancySummaryDto
{
    /// <summary>Vacancies workers can see right now.</summary>
    public int ActivePosts { get; set; }

    /// <summary>Applicants not opened yet, across every vacancy.</summary>
    public int NewCount { get; set; }

    public int WaitingCount { get; set; }

    public int ShortlistedCount { get; set; }

    public int HiredCount { get; set; }
}
