using Zuno.Domain.Common;
using Zuno.Domain.Enums;

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
}
