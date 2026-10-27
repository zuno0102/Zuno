namespace Zuno.Application.Modules.HiringPost.DTOs;

public class HiringPostApplicationDto
{
    public Guid Id { get; set; }

    public Guid WorkerProfileId { get; set; }

    public string WorkerName { get; set; } = string.Empty;

    public string? WorkerPhone { get; set; }

    public string Status { get; set; } = string.Empty;

    public DateTimeOffset AppliedAt { get; set; }

    /// <summary>When the worker accepted or declined the offer. Null while it is still pending.</summary>
    public DateTimeOffset? WorkerRespondedAt { get; set; }

    /// <summary>The figure locked in when this worker was confirmed. Null while still pending.</summary>
    public decimal? AgreedSalaryAmount { get; set; }

    public string? AgreedSalaryUnit { get; set; }

    /// <summary>Their role on one of the business's own events: Supervisor, Lead or Support, or null.</summary>
    public string? Role { get; set; }

    /// <summary>Every raise applied since confirmation, oldest first — the worker's audit trail.</summary>
    /// <summary>Where this worker's wages have got to. See <c>PaymentStatus</c>.</summary>
    public string PaymentStatus { get; set; } = string.Empty;

    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>Set when the worker reports the money never arrived.</summary>
    public string? DisputeReason { get; set; }

    public List<HiringPostSalaryAdjustmentDto> SalaryAdjustments { get; set; } = [];
}
