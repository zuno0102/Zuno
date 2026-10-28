using MediatR;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Events;

/// <summary>
/// The moments on a hiring post that somebody needs telling about.
/// </summary>
/// <remarks>
/// <para>
/// Same discipline as the booking events: one record per real-world moment, user ids rather than
/// email addresses, and the figures carried as they stood — a handler that re-read the wage would
/// compose "raised to ₹1,100" out of whatever the wage has become by the time it runs.
/// </para>
/// <para>
/// These are the worker's side of the app, and the half with the most at stake. A worker learns
/// about work and about money here, and both are time-critical in a way nothing on the customer
/// side is: an invitation nobody sees is a shift that goes unfilled, and a wage nobody is told
/// about is a wage nobody chases.
/// </para>
/// </remarks>
/// <param name="HiringPostId">The post, which is also what tapping the notification opens.</param>
/// <param name="WorkerUserId">The invited worker.</param>
/// <param name="BusinessName">The business doing the hiring.</param>
/// <param name="PostTitle">The job, as the post advertises it.</param>
/// <param name="SalaryAmount">The rate being offered, fixed at the moment of the offer.</param>
/// <param name="SalaryUnit">What that rate is per — an hour, a day, the event.</param>
public record WorkerInvitedToHiringPostEvent(
    Guid HiringPostId,
    Guid WorkerUserId,
    string BusinessName,
    string PostTitle,
    decimal SalaryAmount,
    SalaryUnit SalaryUnit) : INotification;

/// <summary>
/// The business accepted someone who applied. They are hired — the worker asked first, so nothing
/// is left for them to answer.
/// </summary>
public record HiringPostApplicantHiredEvent(
    Guid HiringPostId,
    Guid WorkerUserId,
    string BusinessName,
    string PostTitle) : INotification;

/// <summary>The business turned this applicant down.</summary>
/// <remarks>
/// Worth sending, even though it is bad news. Without it an applicant waits on an answer that has
/// already been given, and keeps the evening free for a job they are not getting.
/// </remarks>
public record HiringPostApplicationRejectedEvent(
    Guid HiringPostId,
    Guid WorkerUserId,
    string BusinessName,
    string PostTitle) : INotification;

/// <summary>Somebody applied to an open post.</summary>
/// <param name="BusinessUserId">The owner, who has applicants to go through.</param>
/// <param name="ApplicantCount">
/// How many are now waiting on an answer, not how many arrived at once. One notification per
/// applicant is correct for a busy post: each is a person deciding whether to keep the day free.
/// </param>
public record HiringPostAppliedEvent(
    Guid HiringPostId,
    Guid BusinessUserId,
    string PostTitle,
    string WorkerName,
    int ApplicantCount) : INotification;

/// <summary>A worker answered the business's offer.</summary>
public record HiringPostOfferAnsweredEvent(
    Guid HiringPostId,
    Guid BusinessUserId,
    string PostTitle,
    string WorkerName,
    bool Accepted) : INotification;

/// <summary>The business raised what it had already agreed to pay this worker.</summary>
public record HiringPostSalaryRaisedEvent(
    Guid HiringPostId,
    Guid WorkerUserId,
    string PostTitle,
    decimal NewAmount,
    SalaryUnit SalaryUnit,
    DateTimeOffset EventDate) : INotification;

/// <summary>
/// Wages were actually sent to a worker.
/// </summary>
/// <remarks>
/// The one notification in this app that is purely good news, and the one a worker will check for.
/// Sent per worker paid, from a pay run that may have covered a dozen of them at once.
/// </remarks>
public record WagesPaidEvent(
    Guid HiringPostId,
    Guid WorkerUserId,
    string PostTitle,
    decimal Amount) : INotification;

/// <summary>
/// A worker says the wages never arrived.
/// </summary>
/// <remarks>
/// Its own event and its own kind, and never batched or made optional. It is the only message in
/// this app about money going missing, and the business cannot answer it without being told.
/// </remarks>
public record WagesDisputedEvent(
    Guid HiringPostId,
    Guid BusinessUserId,
    string WorkerName,
    decimal Amount,
    string Reason) : INotification;
