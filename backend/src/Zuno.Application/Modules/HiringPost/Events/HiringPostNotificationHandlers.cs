using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Events;

// The words for everything that happens on a hiring post. Grouped for the same reason as the
// booking handlers: they share a vocabulary — the same way of saying a wage, a day and a business
// name — and wording that drifts between them cannot be corrected once the rows are sent.
//
// None needs a try/catch: INotificationSender swallows its own failures by contract.

/// <summary>
/// A direct invitation — the business already knew who it wanted.
/// </summary>
/// <remarks>
/// Carries the wage in the title. It is the one fact that decides whether a worker opens this at
/// all, and the figure is the one they will be held to if they accept.
/// </remarks>
public class WorkerInvitedToHiringPostNotificationHandler(
    INotificationSender notifications) : INotificationHandler<WorkerInvitedToHiringPostEvent>
{
    public Task Handle(WorkerInvitedToHiringPostEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.JobInvitation,
            $"{notification.BusinessName} invited you to {notification.PostTitle}",
            $"{NotificationText.Wage(notification.SalaryAmount, notification.SalaryUnit)} — accept or decline.",
            // The post itself, where the details and the two buttons are. Not the Invitations tab:
            // an invitation names one job, and making somebody find it in a list is the hunting
            // this feature exists to end.
            NotificationTarget.HiringPost,
            notification.HiringPostId,
            cancellationToken);
}

/// <summary>The business picked this applicant. Still an offer — they have to answer it.</summary>
public class HiringPostApplicationConfirmedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<HiringPostApplicationConfirmedEvent>
{
    public Task Handle(HiringPostApplicationConfirmedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.JobOfferConfirmed,
            $"{notification.BusinessName} picked you for {notification.PostTitle}",
            "Answer to take the job — the place is not held for long.",
            NotificationTarget.HiringPost,
            notification.HiringPostId,
            cancellationToken);
}

/// <summary>The business turned this applicant down.</summary>
/// <remarks>
/// Points at Find work rather than the post they did not get. The post is closed to them; what
/// they need is the next job, which is the one thing this notification can usefully offer.
/// </remarks>
public class HiringPostApplicationRejectedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<HiringPostApplicationRejectedEvent>
{
    public Task Handle(HiringPostApplicationRejectedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.ApplicationRejected,
            $"{notification.BusinessName} filled {notification.PostTitle}",
            "Your application was not taken forward this time.",
            NotificationTarget.FindWork,
            Guid.Empty,
            cancellationToken);
}

/// <summary>Tells the business somebody has applied.</summary>
public class HiringPostAppliedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<HiringPostAppliedEvent>
{
    public Task Handle(HiringPostAppliedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.NewApplicants,
            $"{notification.WorkerName} applied to {notification.PostTitle}",
            notification.ApplicantCount <= 1
                ? "They are waiting on your answer."
                : $"{notification.ApplicantCount} applicants are now waiting on your answer.",
            NotificationTarget.HiringPostApplicants,
            notification.HiringPostId,
            cancellationToken);
}

/// <summary>Tells the business how a worker answered its offer.</summary>
public class HiringPostOfferAnsweredNotificationHandler(
    INotificationSender notifications) : INotificationHandler<HiringPostOfferAnsweredEvent>
{
    public Task Handle(HiringPostOfferAnsweredEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.OfferAnswered,
            notification.Accepted
                ? $"{notification.WorkerName} accepted {notification.PostTitle}"
                : $"{notification.WorkerName} turned down {notification.PostTitle}",
            // A decline reopens the place, which is the thing the business has to act on.
            notification.Accepted
                ? string.Empty
                : "The place is open again.",
            NotificationTarget.HiringPost,
            notification.HiringPostId,
            cancellationToken);
}

/// <summary>Tells the worker their agreed wage went up.</summary>
public class HiringPostSalaryRaisedNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<HiringPostSalaryRaisedEvent>
{
    public Task Handle(HiringPostSalaryRaisedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.WageRaised,
            $"Your wage {NotificationText.When(notification.EventDate, dateTimeProvider.UtcNow)} "
                + $"went up to {NotificationText.Wage(notification.NewAmount, notification.SalaryUnit)}",
            notification.PostTitle,
            NotificationTarget.HiringPost,
            notification.HiringPostId,
            cancellationToken);
}

/// <summary>Tells the worker their wages were sent.</summary>
/// <remarks>
/// Points at Payments, not the job. Somebody reading this wants to see the money arrive and check
/// what else is owed, which is one screen and not the one the job lives on.
/// </remarks>
public class WagesPaidNotificationHandler(
    INotificationSender notifications) : INotificationHandler<WagesPaidEvent>
{
    public Task Handle(WagesPaidEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.WorkerUserId,
            NotificationKind.WagePaid,
            $"{NotificationText.Money(notification.Amount)} paid for {notification.PostTitle}",
            "Tell us if it does not reach you.",
            NotificationTarget.Payments,
            Guid.Empty,
            cancellationToken);
}

/// <summary>Tells the business a worker says the money never arrived.</summary>
public class WagesDisputedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<WagesDisputedEvent>
{
    public Task Handle(WagesDisputedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.PaymentDisputed,
            $"{notification.WorkerName} reports they were not paid "
                + NotificationText.Money(notification.Amount),
            // Their own words, not a generic line. The reason is what the business needs in order
            // to do anything about it.
            NotificationText.Preview(notification.Reason),
            NotificationTarget.Payouts,
            notification.HiringPostId,
            cancellationToken);
}
