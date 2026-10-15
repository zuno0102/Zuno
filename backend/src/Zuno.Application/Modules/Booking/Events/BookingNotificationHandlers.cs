using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Booking.Events;

// Turns what happened on a booking into the words one person reads about it.
//
// Grouped in one file rather than scattered across nine folders because these handlers share a
// vocabulary: the same business name, the same way of saying a day and an amount
// (NotificationText), the same three or four targets. Wording that drifts between them cannot be
// corrected afterwards — the rows are already sent — so keeping them side by side is the point,
// not a shortcut.
//
// None of them needs a try/catch: INotificationSender swallows its own failures by contract, so a
// dead notification table cannot fail the command that caused it.

/// <summary>Tells the business an order is waiting on it.</summary>
/// <remarks>
/// A second handler on <see cref="BookingCreatedEvent"/>, alongside the email one. They are separate
/// deliveries of the same news, and neither should know the other exists — which is the reason this
/// event was published before notifications were a feature at all.
/// </remarks>
public class BookingCreatedNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingCreatedEvent>
{
    public Task Handle(BookingCreatedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessOwnerUserId,
            NotificationKind.BookingRequested,
            "New booking request",
            $"{notification.ServiceName} "
                + $"{NotificationText.When(notification.ScheduledDate, dateTimeProvider.UtcNow)}.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
}

/// <summary>Tells the customer the job is done, and asks for the rating while it is fresh.</summary>
/// <remarks>
/// Points at the booking with its rating sheet open. The ask is the whole purpose of this one — a
/// notification that only said "work finished" would be news the customer already has, since they
/// were there.
/// </remarks>
public class BookingCompletedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<BookingCompletedEvent>
{
    public Task Handle(BookingCompletedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.CustomerUserId,
            NotificationKind.BookingCompleted,
            $"Work finished. Rate {notification.BusinessName}?",
            "Your rating is what tells the next customer who to trust.",
            NotificationTarget.BookingRating,
            notification.BookingId,
            cancellationToken);
}

/// <summary>Tells the customer their order was taken on.</summary>
public class BookingConfirmedNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingConfirmedEvent>
{
    public Task Handle(BookingConfirmedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.CustomerUserId,
            NotificationKind.BookingConfirmed,
            $"{notification.BusinessName} confirmed your booking",
            $"{notification.ServiceTitle} {NotificationText.When(notification.ScheduledDate, dateTimeProvider.UtcNow)}.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
}

/// <summary>Tells whichever side is being waited on that there is an offer to answer.</summary>
public class BookingTermsProposedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<BookingTermsProposedEvent>
{
    public Task Handle(BookingTermsProposedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.RecipientUserId,
            NotificationKind.BookingTermsProposed,
            $"{notification.ProposerName} proposed {NotificationText.Money(notification.Price)} "
                + $"for {notification.WorkerCount} crew",
            "Your answer is needed before this order can be confirmed.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
}

/// <summary>
/// One assignment, two people told: the customer that their crew is coming, and the worker that
/// they have a job to answer.
/// </summary>
public class BookingCrewAssignedNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingCrewAssignedEvent>
{
    public async Task Handle(BookingCrewAssignedEvent notification, CancellationToken cancellationToken)
    {
        var when = NotificationText.When(notification.ScheduledDate, dateTimeProvider.UtcNow);

        await notifications.NotifyAsync(
            notification.CustomerUserId,
            NotificationKind.BookingCrewAssigned,
            $"Your crew is set for {NotificationText.Day(notification.ScheduledDate, dateTimeProvider.UtcNow)}",
            notification.CrewCount == 1
                ? $"{notification.BusinessName} has one person on your job."
                : $"{notification.BusinessName} has {notification.CrewCount} people on your job.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);

        // The worker's half. Deliberately an ask rather than an announcement — their row is Pending
        // until they answer, and a notification that reads like a confirmation gets ignored.
        await notifications.NotifyAsync(
            notification.AssignedWorkerUserId,
            NotificationKind.JobAssignment,
            $"You're on a job {when}",
            $"{notification.BusinessName} put you on it — accept or decline.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
    }
}

/// <summary>Tells the customer the job has actually begun.</summary>
public class BookingWorkStartedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<BookingWorkStartedEvent>
{
    public Task Handle(BookingWorkStartedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.CustomerUserId,
            NotificationKind.BookingWorkStarted,
            $"{notification.BusinessName} has started your job",
            string.Empty,
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
}

/// <summary>
/// Tells the other party, and every worker who was on it, that the job is off.
/// </summary>
public class BookingCancelledNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingCancelledEvent>
{
    public async Task Handle(BookingCancelledEvent notification, CancellationToken cancellationToken)
    {
        var now = dateTimeProvider.UtcNow;
        var when = NotificationText.When(notification.ScheduledDate, now);

        if (notification.CancelledByCustomer)
        {
            await notifications.NotifyAsync(
                notification.BusinessUserId,
                NotificationKind.BookingCancelledByCustomer,
                $"{notification.CustomerName} cancelled their booking",
                $"The job {when} is off.",
                NotificationTarget.Booking,
                notification.BookingId,
                cancellationToken);
        }
        else
        {
            await notifications.NotifyAsync(
                notification.CustomerUserId,
                NotificationKind.BookingCancelledByBusiness,
                $"{notification.BusinessName} cancelled your booking",
                $"The job {when} is off.",
                NotificationTarget.Booking,
                notification.BookingId,
                cancellationToken);
        }

        if (notification.AssignedWorkerUserIds.Count == 0)
        {
            return;
        }

        // The workers, whoever called it off. They are the ones who would otherwise turn up.
        // Pointed at My jobs rather than the booking: the order is cancelled, so there is nothing
        // left to do on it — what they need is the rest of their week.
        await notifications.NotifyManyAsync(
            notification.AssignedWorkerUserIds,
            NotificationKind.JobCancelled,
            $"Your job {when} was called off",
            "The booking it was part of has been cancelled.",
            NotificationTarget.MyJobs,
            Guid.Empty,
            cancellationToken);
    }
}

/// <summary>A chat message, to the side that did not write it.</summary>
/// <remarks>
/// Titled with the sender's name and bodied with what they said, the way every messaging app does
/// it: the name is what tells somebody whether to open it now.
/// </remarks>
public class BookingMessageSentNotificationHandler(
    INotificationSender notifications) : INotificationHandler<BookingMessageSentEvent>
{
    public Task Handle(BookingMessageSentEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.RecipientUserId,
            NotificationKind.ChatMessage,
            notification.SenderName,
            NotificationText.Preview(notification.Body),
            NotificationTarget.BookingChat,
            notification.BookingId,
            cancellationToken);
}

/// <summary>Tells the business that one of its crew has finished their part.</summary>
public class BookingWorkerFinishedNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingWorkerFinishedEvent>
{
    public Task Handle(BookingWorkerFinishedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.WorkerFinishedWork,
            $"{notification.WorkerName} finished their part of the job",
            $"The job {NotificationText.When(notification.ScheduledDate, dateTimeProvider.UtcNow)}.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
}

/// <summary>Tells the business how a worker answered the job it put them on.</summary>
public class BookingAssignmentAnsweredNotificationHandler(
    INotificationSender notifications,
    IDateTimeProvider dateTimeProvider) : INotificationHandler<BookingAssignmentAnsweredEvent>
{
    public Task Handle(BookingAssignmentAnsweredEvent notification, CancellationToken cancellationToken)
    {
        var when = NotificationText.When(notification.ScheduledDate, dateTimeProvider.UtcNow);

        return notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.AssignmentAnswered,
            notification.Accepted
                ? $"{notification.WorkerName} accepted the job {when}"
                : $"{notification.WorkerName} turned down the job {when}",
            // A decline is the one of the two that needs doing something about.
            notification.Accepted
                ? string.Empty
                : "You'll need somebody else on this one.",
            NotificationTarget.Booking,
            notification.BookingId,
            cancellationToken);
    }
}

/// <summary>Tells the business it was rated.</summary>
/// <remarks>
/// Opens the business's own profile, not the order. The rating is already given and cannot be
/// answered; what it changed is the star average a customer sees before choosing.
/// </remarks>
public class BookingRatedNotificationHandler(
    INotificationSender notifications) : INotificationHandler<BookingRatedEvent>
{
    public Task Handle(BookingRatedEvent notification, CancellationToken cancellationToken) =>
        notifications.NotifyAsync(
            notification.BusinessUserId,
            NotificationKind.RatingReceived,
            notification.Score == 1
                ? "You were rated 1 star"
                : $"You were rated {notification.Score} stars",
            string.Empty,
            NotificationTarget.Profile,
            Guid.Empty,
            cancellationToken);
}
