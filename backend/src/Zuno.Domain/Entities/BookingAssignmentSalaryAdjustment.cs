using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// One raise to the wage of a worker the business put on an order directly — extra hours on the
/// day, say. Append-only and only ever upward, the same as <see cref="HiringPostSalaryAdjustment"/>
/// for workers hired through a post, so the trail is the worker's proof of what was promised.
/// </summary>
public class BookingAssignmentSalaryAdjustment : BaseEntity
{
    public Guid BookingWorkerAssignmentId { get; set; }

    public BookingWorkerAssignment BookingWorkerAssignment { get; set; } = null!;

    public decimal PreviousAmount { get; set; }

    public decimal NewAmount { get; set; }

    public string? Reason { get; set; }
}
