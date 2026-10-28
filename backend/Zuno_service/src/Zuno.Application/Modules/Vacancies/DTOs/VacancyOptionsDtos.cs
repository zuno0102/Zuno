namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>
/// Everything the vacancy forms need from the server — job types and prices from their tables, and
/// the upload rules from configuration — so none of it is built into the app.
/// </summary>
public class VacancyOptionsDto
{
    public List<VacancyJobTypeDto> JobTypes { get; set; } = [];

    public List<VacancyFeePlanDto> FeePlans { get; set; } = [];

    /// <summary>File types a File field accepts, without the dot.</summary>
    public List<string> AllowedFileExtensions { get; set; } = [];

    public long MaxFileSizeBytes { get; set; }
}

public class VacancyJobTypeDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public bool HasFixedLength { get; set; }
}

public class VacancyFeePlanDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public int ListingDays { get; set; }
}
