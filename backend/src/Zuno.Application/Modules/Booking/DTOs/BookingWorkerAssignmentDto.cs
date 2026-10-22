namespace Zuno.Application.Modules.Booking.DTOs;

public class BookingWorkerAssignmentDto
{
    public Guid WorkerProfileId { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    public string? WorkerPhone { get; set; }

    public string? Role { get; set; }

    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Where this worker stands on this order: Awaiting, Active, InProgress, Completed or
    /// Declined.
    /// </summary>
    /// <remarks>
    /// Derived from <see cref="Status"/> together with the order's own progress, rather than being
    /// a sixth value on the assignment enum. A worker who has said yes is "active" until the work
    /// begins and "in progress" once it has — the same row, read against a different clock.
    /// </remarks>
    public string DisplayStatus { get; set; } = string.Empty;

    /// <summary>Their wage for this job, or null when they are paid outside Zuno.</summary>
    public decimal? AgreedSalaryAmount { get; set; }

    /// <summary>PerEvent, PerDay or PerHour. Null exactly when the amount is.</summary>
    public string? AgreedSalaryUnit { get; set; }

    /// <summary>The wage before any raise, when it has been raised; otherwise null.</summary>
    public decimal? OriginalSalaryAmount { get; set; }

    /// <summary>Unpaid, Paid, Failed or Disputed. Only meaningful once a wage is agreed.</summary>
    public string PaymentStatus { get; set; } = string.Empty;

    /// <summary>
    /// Whether this worker can actually be paid — somewhere to send the money is on file.
    /// </summary>
    /// <remarks>
    /// Sent so the crew list can flag it before a pay run rather than after. Razorpay refuses a
    /// payout with no destination, and a business discovering that mid-payment has already
    /// authorised the money.
    /// </remarks>
    public bool HasPayoutDetails { get; set; }

    /// <summary>The crew member is owed money through Zuno.</summary>
    public bool IsPayee => AgreedSalaryAmount.HasValue;
}
