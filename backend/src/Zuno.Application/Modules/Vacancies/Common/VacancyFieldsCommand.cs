using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>
/// Everything a business fills in on the vacancy form. Create and update share it, so the two can
/// never accept different fields or check them differently.
/// </summary>
public abstract class VacancyFieldsCommand
{
    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public Guid JobTypeId { get; set; }

    public Guid? ServiceSubCategoryId { get; set; }

    public int Openings { get; set; } = 1;

    public decimal SalaryMin { get; set; }

    public decimal? SalaryMax { get; set; }

    public VacancyPayPeriod PayPeriod { get; set; } = VacancyPayPeriod.PerMonth;

    public short WorkingDaysPerWeek { get; set; } = 6;

    public TimeOnly? ShiftStart { get; set; }

    public TimeOnly? ShiftEnd { get; set; }

    /// <summary>Required for a job type with a fixed length, and ignored for any other.</summary>
    public short? ContractMonths { get; set; }

    public string? Location { get; set; }

    /// <summary>The workplace, picked on a map or from a search. Both or neither.</summary>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>"Pinned" or "Geocoded", as on hiring posts.</summary>
    public string? LocationPrecision { get; set; }

    /// <summary>The documents and questions every applicant must answer. Replaces the whole set.</summary>
    public List<VacancyRequirementInput> Requirements { get; set; } = [];
}
