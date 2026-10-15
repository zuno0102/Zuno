using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// An immutable record of one raise applied to a confirmed worker's agreed salary —
/// for example extra hours worked on the day. Adjustments are append-only and can only
/// ever increase the amount, so the trail doubles as the worker's proof of what was promised.
/// </summary>
public class HiringPostSalaryAdjustment : BaseEntity
{
    public Guid HiringPostApplicationId { get; set; }

    public HiringPostApplication HiringPostApplication { get; set; } = null!;

    public decimal PreviousAmount { get; set; }

    public decimal NewAmount { get; set; }

    public string? Reason { get; set; }
}
