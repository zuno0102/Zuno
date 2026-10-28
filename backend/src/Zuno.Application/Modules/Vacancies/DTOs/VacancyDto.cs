using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>A vacancy as both sides see it. Counts and payment fields matter to the business only.</summary>
public class VacancyDto
{
    public Guid Id { get; set; }

    public Guid BusinessOwnerProfileId { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessLogoUrl { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public Guid JobTypeId { get; set; }

    public string JobTypeName { get; set; } = string.Empty;

    public Guid? ServiceSubCategoryId { get; set; }

    public string? ServiceSubCategoryName { get; set; }

    public int Openings { get; set; }

    public decimal SalaryMin { get; set; }

    public decimal? SalaryMax { get; set; }

    public VacancyPayPeriod PayPeriod { get; set; }

    public short WorkingDaysPerWeek { get; set; }

    public TimeOnly? ShiftStart { get; set; }

    public TimeOnly? ShiftEnd { get; set; }

    public short? ContractMonths { get; set; }

    public string? Location { get; set; }

    public string? DistrictName { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>From the worker's position, when they gave one.</summary>
    public double? DistanceKm { get; set; }

    public VacancyStatus Status { get; set; }

    /// <summary>Visible to workers right now: open and inside its paid period.</summary>
    public bool IsLive { get; set; }

    /// <summary>Has to be paid for before workers see it — never paid, or the period ran out.</summary>
    public bool NeedsPayment { get; set; }

    /// <summary>Stopped, and can start hiring again without paying.</summary>
    public bool CanResume { get; set; }

    public decimal? FeeAmount { get; set; }

    public DateTimeOffset? PublishedAt { get; set; }

    public DateTimeOffset? ExpiresAt { get; set; }

    public DateTimeOffset? HiringStoppedAt { get; set; }

    public DateTimeOffset CreatedDate { get; set; }

    /// <summary>Everyone still in the running: rejected applicants are not counted.</summary>
    public int ApplicantCount { get; set; }

    /// <summary>Not opened yet — the business's New list.</summary>
    public int NewCount { get; set; }

    /// <summary>Opened, no decision yet — the Waiting list.</summary>
    public int WaitingCount { get; set; }

    public int ShortlistedCount { get; set; }

    public int HiredCount { get; set; }

    public List<VacancyRequirementDto> Requirements { get; set; } = [];

    /// <summary>The signed-in worker's own application, when they have one.</summary>
    public Guid? MyApplicationId { get; set; }

    public VacancyApplicationStatus? MyApplicationStatus { get; set; }

    public DateTimeOffset? MyAppliedAt { get; set; }
}
