using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One worker's assignment to a booking. A booking can require more than one worker
/// (e.g. a catering order needing a crew of 15) — each crew member gets their own row here,
/// with their own role, response, and completion state, independent of the others.
/// </summary>
public class BookingWorkerAssignment : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    public string? Role { get; set; }

    public BookingWorkerAssignmentStatus AssignmentStatus { get; set; } = BookingWorkerAssignmentStatus.Assigned;

    public DateTimeOffset? RespondedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    /// <summary>What this worker is paid for this job, if they are paid through Zuno at all.</summary>
    /// <remarks>
    /// Null means "not paid per job through Zuno" — a regular on a monthly wage, or someone the
    /// business settles with in cash. That is a real answer, not a missing one, and it is why the
    /// wage rollup has <see cref="Enums.BookingWageStatus.NoWagesThroughZuno"/>.
    ///
    /// Before this existed a hand-added worker had no wage anywhere, so an order staffed entirely
    /// by hand owed nobody and counted as settled the moment the work finished — while that crew
    /// had been paid nothing.
    /// </remarks>
    public decimal? AgreedSalaryAmount { get; set; }

    /// <summary>Per event, day or hour. Meaningless without an amount, and refused without one.</summary>
    public SalaryUnit? AgreedSalaryUnit { get; set; }

    /// <summary>How far this worker's wage has got. Only meaningful once a salary is agreed.</summary>
    public PaymentStatus PaymentStatus { get; set; } = PaymentStatus.Unpaid;

    /// <summary>Whether this worker is owed money through Zuno at all.</summary>
    public bool IsPayee => AgreedSalaryAmount.HasValue;
}
