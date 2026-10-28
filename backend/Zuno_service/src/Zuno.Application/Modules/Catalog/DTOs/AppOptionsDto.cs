namespace Zuno.Application.Modules.Catalog.DTOs;

/// <summary>
/// Every limit an app form checks before sending, as the server currently enforces it. The app keeps
/// the shipped values as a fallback for when this has not loaded yet.
/// </summary>
public class AppOptionsDto
{
    public int HiringPostMinDurationMinutes { get; init; }

    public int HiringPostMaxDurationMinutes { get; init; }

    public int HiringPostDefaultDurationMinutes { get; init; }

    public int HiringPostMaxWorkers { get; init; }

    public int OrderMaxCrewSize { get; init; }

    public int ServiceMaxQuestions { get; init; }

    public int ServiceImageSlots { get; init; }

    public int ServiceVideoMaxSeconds { get; init; }

    public long ServiceVideoMaxBytes { get; init; }

    public long ImageMaxBytes { get; init; }

    public int ImageUploadQuality { get; init; }

    public int ImageUploadMaxWidth { get; init; }

    /// <summary>Furthest ahead a date picker reaches, in days.</summary>
    public int MaxDaysAhead { get; init; }

    /// <summary>Furthest ahead a customer may book, in days.</summary>
    public int CustomerBookingMaxDaysAhead { get; init; }

    public int VacancyMaxOpenings { get; init; }

    public int VacancyMaxContractMonths { get; init; }

    public int VacancyMaxFields { get; init; }

    public int VacancyTitleMaxLength { get; init; }

    public int VacancyDescriptionMaxLength { get; init; }

    public int VacancyLocationMaxLength { get; init; }

    public int VacancyFieldNameMaxLength { get; init; }
}
