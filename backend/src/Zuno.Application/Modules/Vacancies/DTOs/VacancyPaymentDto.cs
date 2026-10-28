namespace Zuno.Application.Modules.Vacancies.DTOs;

/// <summary>The listing fee waiting to be paid, and what the app needs to open the payment window.</summary>
public class VacancyPaymentDto
{
    public Guid VacancyId { get; set; }

    public string PlanName { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public int ListingDays { get; set; }

    /// <summary>The order to open Checkout against. Null when there is nothing to collect.</summary>
    public string? ProviderOrderId { get; set; }

    public string? RazorpayKeyId { get; set; }

    /// <summary>
    /// No payment window to open: the plan is free, or collection is simulated (Development only).
    /// The app goes straight to confirming.
    /// </summary>
    public bool NothingToCollect { get; set; }

    /// <summary>Set once the fee is settled without Checkout — a free plan goes live at once.</summary>
    public VacancyDto? Vacancy { get; set; }
}
