using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class Booking : BaseEntity
{
    public Guid CustomerProfileId { get; set; }

    public CustomerProfile CustomerProfile { get; set; } = null!;

    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    public Guid BusinessServiceId { get; set; }

    public BusinessService BusinessService { get; set; } = null!;

    public Guid? BusinessServiceVariantId { get; set; }

    public BusinessServiceVariant? BusinessServiceVariant { get; set; }

    public ICollection<BookingWorkerAssignment> WorkerAssignments { get; set; } = new List<BookingWorkerAssignment>();

    /// <summary>What the customer told the business about this job, in its own words.</summary>
    public ICollection<BookingServiceAnswer> ServiceAnswers { get; set; } = new List<BookingServiceAnswer>();

    /// <summary>Every offer and counter-offer made on this order, oldest first.</summary>
    public ICollection<BookingAgreementProposal> AgreementProposals { get; set; } = new List<BookingAgreementProposal>();

    /// <summary>What the two sides have written to each other about this order.</summary>
    public ICollection<BookingMessage> Messages { get; set; } = new List<BookingMessage>();

    /// <summary>Each party's own clearing of the thread. At most one row per person.</summary>
    public ICollection<BookingThreadClear> ThreadClears { get; set; } = new List<BookingThreadClear>();

    /// <summary>Hiring raised to crew this order. Usually none or one; nothing forbids more.</summary>
    /// <remarks>
    /// Here so the wage rule can be written once as an expression over a booking and run in SQL.
    /// It is <em>not</em> for loading: keep it out of the booking read graph, and never add a
    /// computed wage property to this class that reads it — an unloaded collection would answer
    /// "nobody is owed anything" on a screen about money.
    /// </remarks>
    public ICollection<HiringPost> HiringPosts { get; set; } = new List<HiringPost>();

    public int RequiredWorkerCount { get; set; } = 1;

    public Guid AddressId { get; set; }

    public Address Address { get; set; } = null!;

    public BookingStatus BookingStatus { get; set; } = BookingStatus.Pending;

    public DateTimeOffset ScheduledDate { get; set; }

    public string? Notes { get; set; }

    public decimal PriceQuoted { get; set; }

    /// <summary>What <see cref="PriceQuoted"/> is a price <em>of</em>, copied from the service.</summary>
    /// <remarks>
    /// Snapshotted rather than read live off the service, for the same reason the price itself is:
    /// a business that later reprices its work must not silently restate what an old order was
    /// agreed at.
    ///
    /// It only started mattering with <see cref="Domain.Enums.PriceType.PerPerson"/>. A flat
    /// ₹700 reads correctly with no unit at all, which is why nothing recorded one before; "₹500"
    /// on a per-person order is simply the wrong number on the screen.
    ///
    /// Null on every order placed before this was recorded — those render exactly as they always
    /// have, with no unit.
    /// </remarks>
    public PriceType? PriceType { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }

    public string? CancellationReason { get; set; }

    public Rating? Rating { get; set; }

    /// <summary>When the business marked the work as actually under way.</summary>
    /// <remarks>
    /// What moves an order to <see cref="BookingStatus.InProgress"/>. Previously that happened
    /// the moment one worker accepted, which could be weeks before the event — so "in progress"
    /// said nothing about whether anyone had turned up.
    /// </remarks>
    public DateTimeOffset? WorkStartedAt { get; set; }

    // ---- Crew ------------------------------------------------------------------------------
    //
    // Derived from the assignments rather than stored, so the figures can never disagree with
    // the rows they summarise.

    /// <summary>People on the job: offered and not yet answered, or accepted.</summary>
    public int ActiveCrewCount => WorkerAssignments.Count(a =>
        a.AssignmentStatus is BookingWorkerAssignmentStatus.Assigned
            or BookingWorkerAssignmentStatus.Accepted);

    /// <summary>People who have said yes. Only these can actually work.</summary>
    public int AcceptedCrewCount => WorkerAssignments.Count(a =>
        a.AssignmentStatus == BookingWorkerAssignmentStatus.Accepted);

    public int CompletedCrewCount => WorkerAssignments.Count(a =>
        a.AssignmentStatus == BookingWorkerAssignmentStatus.Completed);

    /// <summary>Whether the job has as many people on it as it needs.</summary>
    /// <remarks>
    /// A crew size of 0 means "not fixed yet — agreed with the customer", not "nobody needed".
    /// Without the guard, <c>ActiveCrewCount >= 0</c> is vacuously true and a per-person order
    /// with nobody hired would report itself fully staffed.
    /// </remarks>
    public bool IsFullyStaffed => RequiredWorkerCount > 0 && ActiveCrewCount >= RequiredWorkerCount;

    public BookingCrewStatus CrewStatus
    {
        get
        {
            // Everyone who was on it has finished, and nobody is still outstanding.
            if (CompletedCrewCount > 0 && ActiveCrewCount == 0)
            {
                return BookingCrewStatus.Done;
            }

            if (ActiveCrewCount == 0)
            {
                return BookingCrewStatus.NotStaffed;
            }

            return IsFullyStaffed
                ? BookingCrewStatus.FullyStaffed
                : BookingCrewStatus.PartStaffed;
        }
    }

    /// <summary>
    /// A short code for this order — "#3F91C27A" — for people rather than machines.
    /// </summary>
    /// <remarks>
    /// Derived from the id, so it needs no column of its own and can never drift out of step with
    /// the row it names. A business running three weddings at once needs something it can say out
    /// loud and match against a hiring post; a full GUID is not that.
    ///
    /// Every byte of the id is folded in rather than slicing the first eight characters off it.
    /// Ids are not always random — seeded and sequentially-generated ones share a long prefix,
    /// and two orders displaying the same code would defeat the whole point of having one.
    /// </remarks>
    public string Reference
    {
        get
        {
            Span<byte> bytes = stackalloc byte[16];
            Id.TryWriteBytes(bytes);

            // FNV-1a. Not a security hash — just a cheap, stable way to let all 128 bits reach
            // the eight characters a person actually reads.
            var hash = 2166136261u;
            foreach (var b in bytes)
            {
                hash = (hash ^ b) * 16777619u;
            }

            return $"#{hash:X8}";
        }
    }
}
