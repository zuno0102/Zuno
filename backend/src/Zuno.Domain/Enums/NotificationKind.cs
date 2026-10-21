namespace Zuno.Domain.Enums;

/// <summary>
/// What a notification is about.
/// </summary>
/// <remarks>
/// Stored alongside the written title and body rather than instead of them. The words are composed
/// when the thing happens — they carry the business's name, the wage, the date — and rewriting them
/// later must not change what a notification already sent said. The kind is for everything the words
/// cannot answer: grouping, counting, and one day letting somebody turn a class of them off.
///
/// Values are explicit because they are persisted. Never renumber one; add to the end.
/// </remarks>
public enum NotificationKind : short
{
    // ---- Reaching a customer ----
    BookingConfirmed = 1,
    BookingTermsProposed = 2,
    BookingCrewAssigned = 3,
    BookingWorkStarted = 4,
    BookingCompleted = 5,
    BookingCancelledByBusiness = 6,

    // ---- Reaching a worker ----
    JobInvitation = 20,
    JobOfferConfirmed = 21,
    JobAssignment = 22,
    WageRaised = 23,
    WagePaid = 24,
    TeamInvitation = 25,
    JobCancelled = 26,
    ApplicationRejected = 27,

    // 28 was StaffRoleChanged, for a business-wide Supervisor or Manager title. That idea is gone:
    // a role now belongs to one job, and the worker is told about the job rather than the title.
    // The number is left unused rather than reassigned — values are persisted, and some phone may
    // still hold a row carrying it.

    // ---- Reaching a business owner ----
    BookingRequested = 40,
    NewApplicants = 41,
    OfferAnswered = 42,
    AssignmentAnswered = 43,
    WorkerFinishedWork = 44,
    BookingCancelledByCustomer = 45,
    RatingReceived = 46,

    /// <summary>
    /// A worker reporting that wages never arrived.
    /// </summary>
    /// <remarks>
    /// Its own kind, and deliberately not folded in with the other payout messages. It is the only
    /// notification in this app about money going missing, and it is the one that must never be
    /// batched away or made optional.
    /// </remarks>
    PaymentDisputed = 47,

    // 48 was StaffAction — a supervisor or manager moving the owner's order along. Nobody but the
    // owner moves an order now, so there is no such actor to report. Left unused, as above.

    // ---- Either side ----
    ChatMessage = 60,

    /// <summary>A message between a business and a worker on its team.</summary>
    /// <remarks>Kept off the bell like <see cref="ChatMessage"/>: its own Messages list counts it.</remarks>
    WorkChatMessage = 61,
}
