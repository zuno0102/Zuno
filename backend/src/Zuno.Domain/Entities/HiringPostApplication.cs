using Zuno.Domain.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Domain.Entities;

public class HiringPostApplication : BaseEntity
{
    public Guid HiringPostId { get; set; }

    public HiringPost HiringPost { get; set; } = null!;

    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    public HiringPostApplicationStatus ApplicationStatus { get; set; } = HiringPostApplicationStatus.Applied;

    /// <summary>When the business answered the application (approved or rejected it).</summary>
    public DateTimeOffset? RespondedAt { get; set; }

    /// <summary>When the worker answered the business's offer (accepted or declined it).</summary>
    public DateTimeOffset? WorkerRespondedAt { get; set; }

    /// <summary>
    /// The salary locked in for this worker at the moment of confirmation, copied from the post.
    /// Null until confirmed. Once set it is the binding figure: later edits to the post's advertised
    /// salary never touch it, and it can only be raised through a <see cref="HiringPostSalaryAdjustment"/>.
    /// This is what protects a worker from a business quietly cutting ₹100 to ₹50 after the work is done.
    /// </summary>
    public decimal? AgreedSalaryAmount { get; set; }

    public SalaryUnit? AgreedSalaryUnit { get; set; }

    /// <summary>How far this worker.s wage for this job has got. See <see cref="PaymentStatus"/>.</summary>
    public PaymentStatus PaymentStatus { get; set; } = PaymentStatus.Unpaid;

    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>Set when the worker says the money never arrived.</summary>
    public string? DisputeReason { get; set; }

    public DateTimeOffset? DisputedAt { get; set; }

    public ICollection<HiringPostSalaryAdjustment> SalaryAdjustments { get; set; } = new List<HiringPostSalaryAdjustment>();

    /// <summary>
    /// Raises this worker's agreed salary — the "five of them came at ₹1,000 and one stayed three
    /// extra hours" case — and records the raise. The crew's pay total is the sum of each worker's
    /// agreed salary, so raising one worker to ₹1,300 is what makes the job owe ₹5,300.
    /// </summary>
    /// <remarks>
    /// Only before payment. Once a payout has been attempted the amount has already left, or is
    /// leaving, at the old figure; raising it afterwards would mark a wage as owed that no pay run
    /// will ever collect.
    /// </remarks>
    /// <returns>The adjustment to save alongside this application.</returns>
    public HiringPostSalaryAdjustment RaiseSalary(decimal newAmount, string? reason)
    {
        // Raising is allowed both for a worker who has accepted and for one still weighing an
        // offer — sweetening a pending offer is legitimate; a declined one is not.
        if (ApplicationStatus is not (HiringPostApplicationStatus.Accepted or HiringPostApplicationStatus.Confirmed))
        {
            throw new DomainException(
                "Only a worker who has accepted, or who has an offer pending, can have their salary adjusted.");
        }

        if (PaymentStatus != PaymentStatus.Unpaid)
        {
            throw new DomainException(
                "This worker's payment has already started, so their salary can no longer be raised.");
        }

        var currentAmount = AgreedSalaryAmount
            ?? throw new DomainException("This application has no agreed salary recorded.");

        if (newAmount <= currentAmount)
        {
            throw new DomainException(
                $"The agreed salary can only be increased. It is currently {currentAmount:0.##}, " +
                $"so the new amount must be greater than that.");
        }

        var adjustment = new HiringPostSalaryAdjustment
        {
            HiringPostApplicationId = Id,
            HiringPostApplication = this,
            PreviousAmount = currentAmount,
            NewAmount = newAmount,
            Reason = reason,
        };

        SalaryAdjustments.Add(adjustment);
        AgreedSalaryAmount = newAmount;
        return adjustment;
    }
}
