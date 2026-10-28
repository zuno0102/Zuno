using MediatR;

namespace Zuno.Application.Modules.Booking.Events;

/// <summary>
/// The moments on a booking that somebody needs telling about.
/// </summary>
/// <remarks>
/// <para>
/// One record per <b>real-world event</b>, not per recipient and not per row changed. A business
/// putting a worker on a job is one thing that happened; it tells the customer their crew is set and
/// tells the worker they have a job, and both come from
/// <see cref="BookingCrewAssignedEvent"/>. Splitting them would be two events that must always be
/// published together, which is one event with a way to forget half of it.
/// </para>
/// <para>
/// <b>Payloads carry user ids, and the facts as they stood.</b> The four events this app had before
/// notifications carried email addresses, which cannot address a notification; and a handler that
/// re-read the wage would compose "raised to ₹1,100" from whatever the wage is by the time it runs.
/// </para>
/// <para>
/// <b>Nobody is told about their own action.</b> Each event names its recipients explicitly for that
/// reason — the actor is never among them, and the handler does not have to work out who did it.
/// </para>
/// <para>
/// All of these are published after <c>SaveChangesAsync</c>, so a notification can never describe a
/// booking that did not save.
/// </para>
/// </remarks>
/// <param name="BookingId">The order, which is also what tapping the notification opens.</param>
/// <param name="CustomerUserId">Who placed it.</param>
/// <param name="BusinessName">The business, named as the customer knows it.</param>
/// <param name="ServiceTitle">What the order is for — the variant where there is one.</param>
public record BookingConfirmedEvent(
    Guid BookingId,
    Guid CustomerUserId,
    string BusinessName,
    string ServiceTitle,
    DateTimeOffset ScheduledDate) : INotification;

/// <summary>
/// One side has put a price and a crew size on the table and is waiting for an answer.
/// </summary>
/// <remarks>
/// Goes to whichever side did not propose. The catalogue only promised the customer this one, but a
/// business that is never told a customer countered is a business whose order sits open until
/// somebody happens to look — the same hunting this feature exists to end.
/// </remarks>
/// <param name="RecipientUserId">The side being waited on.</param>
/// <param name="ProposerName">Who made the offer, as the recipient knows them.</param>
public record BookingTermsProposedEvent(
    Guid BookingId,
    Guid RecipientUserId,
    string ProposerName,
    decimal Price,
    int WorkerCount) : INotification;

/// <summary>
/// A worker has been put on a booking: news for the customer and a job for the worker.
/// </summary>
/// <param name="AssignedWorkerUserId">The worker now on the job, who has to accept or decline.</param>
/// <param name="WorkerName">That worker, for the customer's and the business's wording.</param>
/// <param name="CrewCount">How many are now on the order, after this one.</param>
public record BookingCrewAssignedEvent(
    Guid BookingId,
    Guid CustomerUserId,
    Guid AssignedWorkerUserId,
    string BusinessName,
    string WorkerName,
    int CrewCount,
    DateTimeOffset ScheduledDate) : INotification;

/// <summary>Work has begun on the day.</summary>
public record BookingWorkStartedEvent(
    Guid BookingId,
    Guid CustomerUserId,
    string BusinessName) : INotification;

/// <summary>
/// The order is off.
/// </summary>
/// <remarks>
/// The one event with three sets of recipients: the other party, and every worker who had been put
/// on it. A worker who is not told is a worker who travels to a job that is not happening, which is
/// the most expensive silence in this app.
/// </remarks>
/// <param name="CancelledByCustomer">
/// Which side called it off. Decides who is told — never the one who did it.
/// </param>
/// <param name="AssignedWorkerUserIds">
/// Everyone who had accepted or was still deciding. Already-rejected rows are left out; they were
/// never coming.
/// </param>
public record BookingCancelledEvent(
    Guid BookingId,
    bool CancelledByCustomer,
    Guid CustomerUserId,
    Guid BusinessUserId,
    IReadOnlyCollection<Guid> AssignedWorkerUserIds,
    string BusinessName,
    string CustomerName,
    DateTimeOffset ScheduledDate) : INotification;

/// <summary>A message on a booking's thread, for the side that did not write it.</summary>
/// <param name="SenderName">Who wrote it, as the recipient knows them.</param>
/// <param name="Body">What they wrote. Clipped into the notification, not stored twice in full.</param>
public record BookingMessageSentEvent(
    Guid BookingId,
    Guid RecipientUserId,
    string SenderName,
    string Body) : INotification;

/// <summary>A worker has marked their own part of a booking finished.</summary>
/// <remarks>
/// Distinct from <see cref="BookingCompletedEvent"/>, which is the whole order closing. One crew
/// member finishing is news for the business that has to pay them; the customer hears nothing until
/// the job itself is done.
/// </remarks>
public record BookingWorkerFinishedEvent(
    Guid BookingId,
    Guid BusinessUserId,
    string WorkerName,
    DateTimeOffset ScheduledDate) : INotification;

/// <summary>A worker has accepted or declined the job they were put on.</summary>
public record BookingAssignmentAnsweredEvent(
    Guid BookingId,
    Guid BusinessUserId,
    string WorkerName,
    bool Accepted,
    DateTimeOffset ScheduledDate) : INotification;

/// <summary>The customer has rated a finished booking.</summary>
public record BookingRatedEvent(
    Guid BookingId,
    Guid BusinessUserId,
    int Score) : INotification;
