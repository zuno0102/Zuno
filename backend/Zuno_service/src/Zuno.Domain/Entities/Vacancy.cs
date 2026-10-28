using System.Linq.Expressions;
using Zuno.Domain.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Domain.Entities;

/// <summary>
/// A business's paid listing for long-running work — a shop helper, a receptionist, a one-month
/// contract. Distinct from <see cref="HiringPost"/>, which is crew for one event and is paid through
/// the app: here the app only connects the two sides, and hiring and salary happen outside it.
/// </summary>
/// <remarks>
/// Seen by workers only. A vacancy is live while it is <see cref="VacancyStatus.Open"/> and its paid
/// listing period has not run out; stopping hides it without deleting it, and a stopped vacancy can be
/// reopened for as long as that period lasts.
/// </remarks>
public class Vacancy : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public Guid VacancyJobTypeId { get; set; }

    public VacancyJobType VacancyJobType { get; set; } = null!;

    /// <summary>The kind of work, from the same catalogue the rest of the app uses. Optional.</summary>
    public Guid? ServiceSubCategoryId { get; set; }

    public ServiceSubCategory? ServiceSubCategory { get; set; }

    public int Openings { get; set; } = 1;

    public decimal SalaryMin { get; set; }

    /// <summary>Top of the salary range. Null means a single figure rather than a range.</summary>
    public decimal? SalaryMax { get; set; }

    public VacancyPayPeriod PayPeriod { get; set; } = VacancyPayPeriod.PerMonth;

    public short WorkingDaysPerWeek { get; set; } = 6;

    public TimeOnly? ShiftStart { get; set; }

    public TimeOnly? ShiftEnd { get; set; }

    /// <summary>How many months the job runs. Set only for a job type with a fixed length.</summary>
    public short? ContractMonths { get; set; }

    /// <summary>The address as the business typed it — what a worker reads to find the place.</summary>
    public string? Location { get; set; }

    public Guid? DistrictId { get; set; }

    public District? District { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public HiringPostLocationPrecision LocationPrecision { get; set; } = HiringPostLocationPrecision.None;

    public VacancyStatus VacancyStatus { get; set; } = VacancyStatus.AwaitingPayment;

    /// <summary>The plan of the last order raised. The amount and days are copied, not looked up.</summary>
    public Guid? VacancyFeePlanId { get; set; }

    public VacancyFeePlan? VacancyFeePlan { get; set; }

    public decimal? FeeAmount { get; set; }

    /// <summary>Days the pending order buys, copied from the plan when the order was raised.</summary>
    public int? FeeListingDays { get; set; }

    /// <summary>
    /// The payment provider's order still waiting to be paid. Reused rather than replaced, so tapping
    /// Pay twice can never raise two charges for one listing.
    /// </summary>
    public string? PendingOrderId { get; set; }

    public string? LastPaymentId { get; set; }

    /// <summary>How many times the listing has been paid for. Part of each order's idempotency key.</summary>
    public int PaidCount { get; set; }

    /// <summary>When the vacancy first went live.</summary>
    public DateTimeOffset? PublishedAt { get; set; }

    /// <summary>When the paid listing period ends. Null until the first payment.</summary>
    public DateTimeOffset? ExpiresAt { get; set; }

    public DateTimeOffset? HiringStoppedAt { get; set; }

    public ICollection<VacancyRequirement> Requirements { get; set; } = new List<VacancyRequirement>();

    public ICollection<VacancyApplication> Applications { get; set; } = new List<VacancyApplication>();

    /// <summary>The key a payment order for the next listing period is raised under.</summary>
    /// <remarks>
    /// Stable until that period is paid, so a retried request reaches the same order rather than a
    /// second charge. Kept within Razorpay's 40-character receipt limit.
    /// </remarks>
    public string NextPaymentKey => $"vac{Id:N}{PaidCount}";

    /// <summary>Whether workers can see and apply to this vacancy right now.</summary>
    public bool IsLiveAt(DateTimeOffset now) =>
        VacancyStatus == VacancyStatus.Open && ExpiresAt > now;

    /// <summary><see cref="IsLiveAt"/> in a form the database can run.</summary>
    public static Expression<Func<Vacancy, bool>> LiveAt(DateTimeOffset now) =>
        v => v.VacancyStatus == VacancyStatus.Open && v.ExpiresAt > now;

    /// <summary>
    /// Whether the business has to pay before workers can see it: never paid, or the paid period is
    /// over. Paying while still live is allowed too, and extends the period.
    /// </summary>
    public bool NeedsPaymentAt(DateTimeOffset now) =>
        VacancyStatus == VacancyStatus.AwaitingPayment || ExpiresAt is null || ExpiresAt <= now;

    /// <summary>Whether starting to hire again is on offer: stopped, and still inside the paid period.</summary>
    public bool CanResumeAt(DateTimeOffset now) =>
        VacancyStatus == VacancyStatus.Stopped && ExpiresAt > now;

    /// <summary>Copies a plan's terms onto the vacancy for the order about to be raised.</summary>
    public void PriceWith(VacancyFeePlan plan)
    {
        if (VacancyFeePlanId != plan.Id || FeeAmount != plan.Amount || FeeListingDays != plan.ListingDays)
        {
            // Different terms mean a different order: the old one would charge the old price.
            PendingOrderId = null;
        }

        VacancyFeePlanId = plan.Id;
        FeeAmount = plan.Amount;
        FeeListingDays = plan.ListingDays;
    }

    /// <summary>
    /// Records a verified payment: the vacancy goes live, or its period is extended.
    /// </summary>
    /// <remarks>
    /// The new period starts from the old expiry when that is still ahead, so renewing early never
    /// throws away days already paid for. A stopped vacancy stays stopped — paying is not the same as
    /// deciding to hire again.
    /// </remarks>
    public void RecordPayment(string? paymentId, DateTimeOffset now)
    {
        if (FeeListingDays is not { } days || days <= 0)
        {
            throw new DomainException("There is no listing fee waiting to be paid on this vacancy.");
        }

        var from = ExpiresAt is { } current && current > now ? current : now;

        ExpiresAt = from.AddDays(days);
        PublishedAt ??= now;
        LastPaymentId = paymentId;
        PendingOrderId = null;
        PaidCount++;

        if (VacancyStatus == VacancyStatus.AwaitingPayment)
        {
            VacancyStatus = VacancyStatus.Open;
        }
    }

    public void StopHiring(DateTimeOffset now)
    {
        if (VacancyStatus != VacancyStatus.Open)
        {
            throw new DomainException(VacancyStatus == VacancyStatus.Stopped
                ? "Hiring for this vacancy is already stopped."
                : "This vacancy is not live yet. Pay the listing fee first.");
        }

        VacancyStatus = VacancyStatus.Stopped;
        HiringStoppedAt = now;
    }

    public void ResumeHiring(DateTimeOffset now)
    {
        if (VacancyStatus != VacancyStatus.Stopped)
        {
            throw new DomainException("Only a stopped vacancy can start hiring again.");
        }

        if (!CanResumeAt(now))
        {
            throw new DomainException(
                "The paid listing period for this vacancy has ended. Pay the listing fee to post it again.");
        }

        VacancyStatus = VacancyStatus.Open;
        HiringStoppedAt = null;
    }
}
