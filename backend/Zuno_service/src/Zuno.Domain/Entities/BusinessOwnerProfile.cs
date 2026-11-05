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

    /// <summary>
    /// Where customers pay the business by UPI, e.g. <c>joyevents@okhdfcbank</c>. Every payment QR the
    /// business shows is made from it — in Service and in Rent, which copies it from here. Required to
    /// save the profile; null only for a business that has not finished its profile yet.
    /// </summary>
    public string? UpiId { get; set; }

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

    /// <summary>
    /// The overall customer rating across every business line (Service and Rent), worked out with
    /// <see cref="ValueObjects.FairRating"/>. Null until there are enough ratings to judge.
    /// </summary>
    public decimal? CustomerRatingAverage { get; set; }

    /// <summary>Customer ratings across every business line: <see cref="ServiceRatingCount"/> + <see cref="RentRatingCount"/>.</summary>
    public int CustomerReviewCount { get; set; }

    /// <summary>All the stars customers gave this business's Service orders, added together.</summary>
    public decimal ServiceRatingSum { get; set; }

    /// <summary>How many Service orders customers rated.</summary>
    public int ServiceRatingCount { get; set; }

    /// <summary>All the stars customers gave its Rent orders, as last reported by the Rent API.</summary>
    public decimal RentRatingSum { get; set; }

    /// <summary>How many Rent orders customers rated, as last reported by the Rent API.</summary>
    public int RentRatingCount { get; set; }

    /// <summary>Rent orders returned and paid in full, as last reported by the Rent API.</summary>
    public int RentSuccessfulOrders { get; set; }

    /// <summary>When the Rent figures above were last copied from the Rent API. Null if never.</summary>
    public DateTimeOffset? RentReputationAt { get; set; }

    /// <summary>Jobs seen through on every line — what the level counts.</summary>
    public int TotalSuccessfulJobs => CompletedJobCount + RentSuccessfulOrders;

    public decimal? WorkerRatingAverage { get; set; }

    public int WorkerReviewCount { get; set; }

    /// <summary>Unresolved "I was never paid" reports. Any open dispute caps the level at 1.</summary>
    public int OpenDisputeCount { get; set; }

    /// <summary>1–5, from <see cref="BusinessLevel"/>. Shown to customers as a trust badge.</summary>
    public int Level { get; set; } = 1;

    /// <summary>When the business reached its current level. Null for a level held since before this was recorded.</summary>
    public DateTimeOffset? LevelSince { get; set; }

    /// <summary>When the business first fell below its current level's rules. Null while it meets them.</summary>
    public DateTimeOffset? LevelBelowSince { get; set; }

    public DateTimeOffset? LevelRecalculatedAt { get; set; }
}
