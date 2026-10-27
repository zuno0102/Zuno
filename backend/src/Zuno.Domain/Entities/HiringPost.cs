using System.Linq.Expressions;
using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// A business's open call for extra workers for a specific event (e.g. "Marriage catering
/// hiring") — distinct from <see cref="BusinessWorker"/> invites, which target one specific
/// known person. Any worker in the app can see and apply to an open post.
/// </summary>
public class HiringPost : BaseEntity
{
    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    /// <summary>
    /// The customer booking this crew is being hired for, when there is one.
    /// </summary>
    /// <remarks>
    /// Null for a standalone post — a business hiring for its own event rather than against an
    /// order. When it is set, a worker accepting the offer is assigned to that booking directly,
    /// which is the whole point of the link: the business should not have to hire someone and
    /// then go and pick them off a list a second time.
    /// </remarks>
    public Guid? BookingId { get; set; }

    public Booking? Booking { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? ImageUrl { get; set; }

    public DateTimeOffset EventDate { get; set; }

    /// <summary>
    /// How long the work runs from <see cref="EventDate"/>. Without this a job is an instant in
    /// time, and two jobs at 3pm and 4pm on the same day look like no clash at all — so this is
    /// what makes double-booking detectable.
    /// </summary>
    public int DurationMinutes { get; set; } = 120;

    /// <summary>Shortest job a post may describe.</summary>
    public const int MinDurationMinutes = 15;

    /// <summary>Longest job a post may describe: one day. Queries rely on it as a bound.</summary>
    public const int MaxDurationMinutes = 1440;

    /// <summary>
    /// When the crew actually started. Null until the business says so on the day.
    /// </summary>
    /// <remarks>
    /// Deliberately an explicit act rather than something derived from <see cref="EventDate"/>.
    /// A date arriving proves nothing — the crew may never have turned up — and without a real
    /// starting point there is no honest way to say a job is under way rather than merely due.
    /// </remarks>
    public DateTimeOffset? WorkStartedAt { get; set; }

    /// <summary>When the work actually finished. Null until the business marks it done.</summary>
    public DateTimeOffset? WorkCompletedAt { get; set; }

    /// <summary>
    /// When the last worker on this job was paid. Set once and never cleared — it is the moment the
    /// hiring genuinely ended, and the only thing that credits the business's record.
    /// </summary>
    public DateTimeOffset? SettledAt { get; set; }

    /// <summary>
    /// When the business said it will manage with the crew it has. Null while still hiring.
    /// Set once: a stopped post never reopens, not even when an accepted worker drops out.
    /// </summary>
    public DateTimeOffset? HiringStoppedAt { get; set; }

    /// <summary>The window this job occupies in a worker's day.</summary>
    public DateTimeOffset EventEndDate => EventDate.AddMinutes(DurationMinutes);

    /// <summary>
    /// Whether hiring for this job is over for good: stopped by the business, the work marked
    /// done, or the scheduled end gone by. A job already under way still hires — a worker who
    /// can arrive late is better than one short for the rest of the day.
    /// </summary>
    public bool IsHiringOver(DateTimeOffset now) =>
        HiringStoppedAt is not null || WorkCompletedAt is not null || EventEndDate <= now;

    /// <summary>Whether a worker can apply, be offered a place, or accept one right now.</summary>
    public bool IsAcceptingWorkers(DateTimeOffset now) =>
        !IsHiringOver(now) && HiringPostStatus == HiringPostStatus.Open;

    /// <summary>
    /// <see cref="IsHiringOver"/> negated, in a form the database can run. The first date test is
    /// redundant on its own but lets the (status, event_date) index range-scan: nothing that started
    /// more than <see cref="MaxDurationMinutes"/> ago can still be running.
    /// </summary>
    public static Expression<Func<HiringPost, bool>> StillHiringAt(DateTimeOffset now)
    {
        var earliestLiveStart = now.AddMinutes(-MaxDurationMinutes);
        return p => p.HiringStoppedAt == null
            && p.WorkCompletedAt == null
            && p.EventDate > earliestLiveStart
            && p.EventDate.AddMinutes(p.DurationMinutes) > now;
    }

    /// <summary>
    /// Posts whose time ran out with nobody ever hired: nothing was worked and nothing is owed.
    /// Hidden from the business at once and soft-deleted by the cleanup job.
    /// </summary>
    public static Expression<Func<HiringPost, bool>> UnfilledAndOverAt(DateTimeOffset now) =>
        p => p.WorkStartedAt == null
            && p.EventDate.AddMinutes(p.DurationMinutes) <= now
            && !p.Applications.Any(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted);

    /// <summary>The exact opposite of <see cref="UnfilledAndOverAt"/>: still live, or somebody worked it.</summary>
    public static Expression<Func<HiringPost, bool>> WorthKeepingAt(DateTimeOffset now) =>
        p => p.WorkStartedAt != null
            || p.EventDate.AddMinutes(p.DurationMinutes) > now
            || p.Applications.Any(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted);

    /// <summary>
    /// The free-text job address, as the business typed it. Still what a worker reads.
    /// </summary>
    /// <remarks>
    /// Kept alongside the structured fields below rather than replaced by them: "behind the temple,
    /// Nila Nagar" is how somebody finds the venue on the day, and no coordinate conveys that.
    /// It also serves as the hint the geocoder is given.
    /// </remarks>
    public string? Location { get; set; }

    /// <summary>The district the job is in. Required on new posts, nullable for the ones that predate it.</summary>
    /// <remarks>
    /// A label and a last resort, not a measure. It groups the feed, backs a cheap secondary filter,
    /// and supplies a centre point when nothing finer could be resolved.
    /// </remarks>
    public Guid? DistrictId { get; set; }

    public District? District { get; set; }

    /// <summary>
    /// Where the job is. The only thing distance is ever computed from.
    /// </summary>
    /// <remarks>
    /// This is the JOB, not the business. A caterer in Kochi running a wedding in Trivandrum is a
    /// Trivandrum job, and a worker in Trivandrum has to be able to find it — which is the whole
    /// reason this lives on the post rather than being read off the business's address.
    /// </remarks>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>How the coordinates above were arrived at. Set when written, never recomputed.</summary>
    public HiringPostLocationPrecision LocationPrecision { get; set; } =
        HiringPostLocationPrecision.None;

    /// <summary>Whether this post can take part in a distance search at all.</summary>
    public bool HasPosition => Latitude is not null && Longitude is not null;

    /// <summary>
    /// The kind of work this is, inside the category — "Interior wall painting" rather than
    /// just "Painting".
    /// </summary>
    /// <remarks>
    /// Optional, and the single most useful thing on the post for a worker: it is what lets
    /// them tell at a glance whether the job is one they actually do, instead of opening every
    /// painting post to find out.
    /// </remarks>
    public Guid? ServiceSubCategoryId { get; set; }

    public ServiceSubCategory? ServiceSubCategory { get; set; }

    public int WorkersNeeded { get; set; } = 1;

    /// <summary>
    /// What the business offers each hired worker. Advertised up front so applicants know the
    /// terms before applying, and snapshotted onto the application once confirmed — see
    /// <see cref="HiringPostApplication.AgreedSalaryAmount"/>. Editing this figure downwards is
    /// blocked once anyone has been confirmed.
    /// </summary>
    public decimal SalaryAmount { get; set; }

    public SalaryUnit SalaryUnit { get; set; } = SalaryUnit.PerEvent;

    public HiringPostStatus HiringPostStatus { get; set; } = HiringPostStatus.Open;

    public ICollection<HiringPostApplication> Applications { get; set; } = new List<HiringPostApplication>();

    /// <summary>
    /// Workers who have actually accepted. Only these fill the vacancy — a business approval
    /// the worker has not answered yet leaves the slot open. Requires <see cref="Applications"/>
    /// to be loaded.
    /// </summary>
    public int ConfirmedCount =>
        Applications.Count(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted);

    /// <summary>Offers approved by the business and still sitting with the worker.</summary>
    public int PendingOfferCount =>
        Applications.Count(a => a.ApplicationStatus == HiringPostApplicationStatus.Confirmed);

    /// <summary>Everyone actually working the event.</summary>
    public int FilledCount => ConfirmedCount;

    public bool IsFullyStaffed => FilledCount >= WorkersNeeded;

    /// <summary>
    /// The crew size every screen shows. Once the business stops hiring with people on board, the
    /// job is for the crew it has: 4 of 5 hired becomes a job for 4, and the place never filled
    /// is not shown as missing to the business or the workers. <see cref="WorkersNeeded"/> keeps
    /// the original target for the record. With nobody hired the target stays rather than reading
    /// "0 of 0"; such a post shows as "Nobody was hired". Requires <see cref="Applications"/> to be
    /// loaded.
    /// </summary>
    public int CrewSize => HiringStoppedAt is not null && FilledCount > 0 ? FilledCount : WorkersNeeded;

    /// <summary>
    /// Whether another worker can be offered a place.
    /// </summary>
    /// <remarks>
    /// Only accepted workers count. An outstanding offer reserves nothing, so a business can line
    /// up backups instead of having a place frozen by someone who never replies. Over-hiring is
    /// prevented at the other end: accepting is capped by <see cref="IsFullyStaffed"/>, so the
    /// first to say yes takes the place and the rest are told it has gone.
    /// </remarks>
    public bool CanOfferAnotherWorker => FilledCount < WorkersNeeded;

    /// <summary>
    /// Whether anyone is relying on the advertised salary — accepted workers obviously, but
    /// also those still weighing an offer, who are deciding on that exact figure, and offline
    /// hires recorded against it.
    /// </summary>
    public bool HasCommittedWorkers => FilledCount + PendingOfferCount > 0;

    /// <summary>
    /// Keeps the post's open/closed state in step with its staffing, which is the only thing
    /// that decides it: a post is Open exactly while it still needs people who have said yes.
    /// Called after any change to the accepted head count or to <see cref="WorkersNeeded"/>,
    /// so a declined offer reopens the vacancy on its own — unless hiring was stopped.
    /// </summary>
    public void SyncStatusToStaffing() =>
        HiringPostStatus = IsFullyStaffed || HiringStoppedAt is not null
            ? HiringPostStatus.Closed
            : HiringPostStatus.Open;

    // ---- Settlement -------------------------------------------------------------------------
    //
    // "Completed" meant three unrelated things before this: every place filled, the event date
    // gone, and the business having marked the work done. None of them says anyone was paid, and
    // a business could finish all three while quietly stiffing half the crew. The properties
    // below add the state that actually closes a hiring out.

    /// <summary>Everyone owed money for this job.</summary>
    public IEnumerable<(Guid Id, string Name, decimal Amount, PaymentStatus Status)> Payees =>
        Applications
            .Where(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
            .Select(a => (
                a.Id,
                a.WorkerProfile?.User is null
                    ? "Worker"
                    : $"{a.WorkerProfile.User.FirstName} {a.WorkerProfile.User.LastName}".Trim(),
                a.AgreedSalaryAmount ?? 0m,
                a.PaymentStatus));

    /// <summary>What the whole crew is owed. The figure the server calculates — never the client.</summary>
    public decimal TotalPayable => Payees.Sum(p => p.Amount);

    /// <summary>Still owed: everything not yet settled.</summary>
    public decimal OutstandingAmount => Payees
        .Where(p => p.Status is not PaymentStatus.Paid)
        .Sum(p => p.Amount);

    public int PayeeCount => Payees.Count();

    public int PaidPayeeCount => Payees.Count(p => p.Status == PaymentStatus.Paid);

    public bool HasDisputedPayment => Payees.Any(p => p.Status == PaymentStatus.Disputed);

    /// <summary>
    /// Every worker on this job has been paid. Vacuously false when nobody was hired — an empty
    /// post has not been settled, it simply never ran.
    /// </summary>
    public bool IsFullySettled => PayeeCount > 0 && Payees.All(p => p.Status == PaymentStatus.Paid);

    /// <summary>
    /// The whole hiring is finished: the work was done <em>and</em> everyone was paid. This — not
    /// <see cref="WorkCompletedAt"/> — is what increments a business's completed-job count, so
    /// skipping a worker's wages costs the business the credit for the entire job.
    /// </summary>
    public bool IsFullyComplete => WorkCompletedAt is not null && IsFullySettled;

    /// <summary>
    /// Stamps <see cref="SettledAt"/> the first time every worker is paid. Idempotent: calling it
    /// again after a later change never moves the original settlement moment.
    /// </summary>
    public void SyncSettlement(DateTimeOffset now)
    {
        if (IsFullySettled && SettledAt is null)
        {
            SettledAt = now;
        }
    }
}
