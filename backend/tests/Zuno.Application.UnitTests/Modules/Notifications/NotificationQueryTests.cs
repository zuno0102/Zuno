using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.Commands.MarkAllNotificationsRead;
using Zuno.Application.Modules.Notifications.Commands.MarkNotificationRead;
using Zuno.Application.Modules.Notifications.Queries.GetMyNotifications;
using Zuno.Application.Modules.Notifications.Queries.GetUnreadNotificationCount;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Notifications;

/// <summary>
/// Reading the list, counting the badge, and marking things read.
/// </summary>
/// <remarks>
/// The access rule is the reason most of these exist: a notification is addressed to one person and
/// says what they were told about their own money and their own jobs. Somebody else's is not
/// refused, it is simply not found — a refusal would confirm it exists.
/// </remarks>
public class NotificationQueryTests
{
    private readonly Mock<ICurrentUserService> _currentUser = new();
    private readonly Mock<IDateTimeProvider> _clock = new();
    private readonly Mock<IApplicationDbContext> _db = new();

    private readonly Guid _me = Guid.NewGuid();
    private readonly Guid _someoneElse = Guid.NewGuid();

    private static readonly DateTimeOffset Now = new(2025, 11, 12, 9, 30, 0, TimeSpan.Zero);

    public NotificationQueryTests()
    {
        _currentUser.Setup(c => c.UserId).Returns(_me);
        _clock.Setup(c => c.UtcNow).Returns(Now);
    }

    private Notification Mine(
        int minutesAgo = 0,
        DateTimeOffset? readAt = null,
        NotificationTarget target = NotificationTarget.Booking,
        Guid? targetId = null) => new()
        {
            Id = Guid.NewGuid(),
            UserId = _me,
            Kind = NotificationKind.BookingConfirmed,
            Title = "Boss T confirmed your booking",
            Body = "Wedding catering on Saturday.",
            Target = target,
            TargetId = targetId ?? Guid.NewGuid(),
            ReadAt = readAt,
            CreatedDate = Now.AddMinutes(-minutesAgo),
        };

    private void Given(params Notification[] notifications) =>
        _db.Setup(d => d.Notifications).Returns(TestDbSet.From(notifications));

    // ---- the list ----------------------------------------------------------------------------

    [Fact]
    public async Task Only_my_own_notifications_come_back()
    {
        Given(
            Mine(),
            new Notification { UserId = _someoneElse, Title = "Not yours", Body = string.Empty });

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery(), default);

        result.Should().HaveCount(1);
        result.Single().Title.Should().Be("Boss T confirmed your booking");
    }

    [Fact]
    public async Task Newest_first_because_that_is_where_somebody_opening_this_is_looking()
    {
        Given(
            Mine(minutesAgo: 60),
            Mine(minutesAgo: 1),
            Mine(minutesAgo: 30));

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery(), default);

        result.Select(n => n.CreatedAt).Should().BeInDescendingOrder();
    }

    /// <remarks>
    /// The cap is applied here rather than trusted from the request, so a client cannot ask for
    /// somebody's entire history in one call.
    /// </remarks>
    [Fact]
    public async Task A_request_for_everything_is_capped()
    {
        Given(Enumerable.Range(0, 150).Select(i => Mine(minutesAgo: i)).ToArray());

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery { Take = 5_000 }, default);

        result.Should().HaveCount(100);
    }

    [Fact]
    public async Task Unread_only_leaves_out_what_has_been_seen()
    {
        Given(
            Mine(minutesAgo: 1),
            Mine(minutesAgo: 2, readAt: Now.AddMinutes(-1)));

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery { UnreadOnly = true }, default);

        result.Should().HaveCount(1);
        result.Single().IsUnread.Should().BeTrue();
    }

    /// <remarks>
    /// Guid.Empty is how "this target needs no id" is stored. The app should get nothing rather
    /// than a row of zeroes it has to know to test against.
    /// </remarks>
    [Fact]
    public async Task A_target_that_needs_no_id_comes_back_without_one()
    {
        Given(Mine(target: NotificationTarget.Invitations, targetId: Guid.Empty));

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery(), default);

        result.Single().Target.Should().Be("Invitations");
        result.Single().TargetId.Should().BeNull();
    }

    [Fact]
    public async Task Kind_and_target_leave_as_names_not_numbers()
    {
        Given(Mine(target: NotificationTarget.BookingRating));

        var result = await new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery(), default);

        result.Single().Kind.Should().Be("BookingConfirmed");
        result.Single().Target.Should().Be("BookingRating");
    }

    // ---- the badge ---------------------------------------------------------------------------

    [Fact]
    public async Task The_badge_counts_my_unread_and_nothing_else()
    {
        Given(
            Mine(),
            Mine(),
            Mine(readAt: Now),
            new Notification { UserId = _someoneElse, Title = "Not yours", Body = string.Empty });

        var result = await new GetUnreadNotificationCountQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetUnreadNotificationCountQuery(), default);

        result.UnreadCount.Should().Be(2);
    }

    // ---- marking one read --------------------------------------------------------------------

    [Fact]
    public async Task Opening_one_marks_it_read()
    {
        var notification = Mine();
        Given(notification);

        await new MarkNotificationReadCommandHandler(_currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkNotificationReadCommand { NotificationId = notification.Id }, default);

        notification.ReadAt.Should().Be(Now);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    /// <remarks>
    /// The app fires this as it navigates, so a retry on a flaky connection must not become an
    /// error shown instead of the screen the person asked for.
    /// </remarks>
    [Fact]
    public async Task Marking_it_read_twice_keeps_the_first_time_and_does_not_fail()
    {
        var firstOpened = Now.AddHours(-2);
        var notification = Mine(readAt: firstOpened);
        Given(notification);

        var act = () => new MarkNotificationReadCommandHandler(
                _currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkNotificationReadCommand { NotificationId = notification.Id }, default);

        await act.Should().NotThrowAsync();
        notification.ReadAt.Should().Be(firstOpened);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    /// <remarks>
    /// Not found rather than forbidden. A refusal would confirm that a guessed id belongs to a real
    /// notification, which is already more than a stranger should learn.
    /// </remarks>
    [Fact]
    public async Task Somebody_elses_notification_is_simply_not_found()
    {
        var theirs = new Notification
        {
            Id = Guid.NewGuid(),
            UserId = _someoneElse,
            Title = "Not yours",
            Body = string.Empty,
        };
        Given(theirs);

        var act = () => new MarkNotificationReadCommandHandler(
                _currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkNotificationReadCommand { NotificationId = theirs.Id }, default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        theirs.ReadAt.Should().BeNull();
    }

    // ---- clearing the badge ------------------------------------------------------------------

    [Fact]
    public async Task Clearing_the_badge_marks_every_unread_one_and_leaves_the_rows()
    {
        var alreadyRead = Now.AddDays(-1);
        var one = Mine();
        var two = Mine();
        var old = Mine(readAt: alreadyRead);
        Given(one, two, old);

        await new MarkAllNotificationsReadCommandHandler(
                _currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkAllNotificationsReadCommand(), default);

        one.ReadAt.Should().Be(Now);
        two.ReadAt.Should().Be(Now);
        old.ReadAt.Should().Be(alreadyRead);
    }

    [Fact]
    public async Task Clearing_an_already_clear_badge_touches_nothing()
    {
        Given(Mine(readAt: Now.AddDays(-1)));

        await new MarkAllNotificationsReadCommandHandler(
                _currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkAllNotificationsReadCommand(), default);

        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task Clearing_the_badge_never_reaches_somebody_elses_notifications()
    {
        var theirs = new Notification
        {
            Id = Guid.NewGuid(),
            UserId = _someoneElse,
            Title = "Not yours",
            Body = string.Empty,
        };
        Given(Mine(), theirs);

        await new MarkAllNotificationsReadCommandHandler(
                _currentUser.Object, _clock.Object, _db.Object)
            .Handle(new MarkAllNotificationsReadCommand(), default);

        theirs.ReadAt.Should().BeNull();
    }

    // ---- signed out --------------------------------------------------------------------------

    [Fact]
    public async Task Nobody_signed_in_means_nothing_to_read()
    {
        _currentUser.Setup(c => c.UserId).Returns((Guid?)null);
        Given(Mine());

        var act = () => new GetMyNotificationsQueryHandler(_currentUser.Object, _db.Object)
            .Handle(new GetMyNotificationsQuery(), default);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }
}
