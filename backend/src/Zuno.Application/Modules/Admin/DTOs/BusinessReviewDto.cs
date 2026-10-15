namespace Zuno.Application.Modules.Admin.DTOs;

/// <summary>A business as an admin sees it when deciding whether to let customers find it.</summary>
public class BusinessReviewDto
{
    public Guid Id { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessType { get; set; }

    public string? GstNumber { get; set; }

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public string OwnerName { get; set; } = string.Empty;

    public string? OwnerEmail { get; set; }

    public string? OwnerPhone { get; set; }

    /// <summary>Pending, Verified or Rejected.</summary>
    public string VerificationStatus { get; set; } = string.Empty;

    public DateTimeOffset? VerifiedAt { get; set; }

    /// <summary>How much they have actually listed — the substance of the decision.</summary>
    public int ActiveServiceCount { get; set; }

    public int CompletedJobCount { get; set; }

    public int OpenDisputeCount { get; set; }

    public DateTimeOffset RegisteredAt { get; set; }
}
