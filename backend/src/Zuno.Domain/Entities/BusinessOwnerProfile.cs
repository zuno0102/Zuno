using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class BusinessOwnerProfile : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessType { get; set; }

    public string? GstNumber { get; set; }

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public Guid? BusinessAddressId { get; set; }

    public Address? BusinessAddress { get; set; }

    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;

    public DateTimeOffset? VerifiedAt { get; set; }

    public ICollection<BusinessService> Services { get; set; } = new List<BusinessService>();

    public ICollection<BusinessWorker> Workers { get; set; } = new List<BusinessWorker>();

    public ICollection<Booking> Bookings { get; set; } = new List<Booking>();

    // ---- Reputation -------------------------------------------------------------------------
    //
    // Denormalised rather than computed on read: these appear on every customer search result, and
    // recomputing them per row would mean aggregating every job and review the business has ever
    // had. They are recalculated by BusinessReputationService whenever a job settles or a review
    // lands, which is rare compared to how often they are read.

    /// <summary>
    /// Jobs where the work was finished <em>and</em> every worker was paid. Deliberately not a
    /// count of completed events: a business that never pays its crew never sees this rise, so
    /// the number stands for jobs actually seen through rather than jobs merely worked.
    /// </summary>
    public int CompletedJobCount { get; set; }

    public decimal? CustomerRatingAverage { get; set; }

    public int CustomerReviewCount { get; set; }

    public decimal? WorkerRatingAverage { get; set; }

    public int WorkerReviewCount { get; set; }

    /// <summary>Unresolved "I was never paid" reports. Any open dispute caps the level at 1.</summary>
    public int OpenDisputeCount { get; set; }

    /// <summary>1–5, from <see cref="BusinessLevel"/>. Shown to customers as a trust badge.</summary>
    public int Level { get; set; } = 1;

    public DateTimeOffset? LevelRecalculatedAt { get; set; }
}
