using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Notifications;

/// <summary>
/// The guarantees the whole feature rests on: a notification is never more important than the
/// thing it is about, and one real-world event produces one row per person.
/// </summary>
public class DatabaseNotificationSenderTests
{
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<DbSet<Notification>> _notifications = new();
    private readonly Mock<ILogger<DatabaseNotificationSender>> _logger = new();
    private readonly List<Notification> _added = [];

    private readonly DatabaseNotificationSender _sut;

    public DatabaseNotificationSenderTests()
    {
        _notifications
            .Setup(s => s.Add(It.IsAny<Notification>()))
            .Callback<Notification>(_added.Add);

        _db.Setup(d => d.Notifications).Returns(_notifications.Object);

        _sut = new DatabaseNotificationSender(_db.Object, _logger.Object);
    }

    private Task Notify(Guid userId) => _sut.NotifyAsync(
        userId,
        NotificationKind.BookingConfirmed,
        "Boss T confirmed your booking",
        "Wedding catering on Saturday.",
        NotificationTarget.Booking,
        Guid.NewGuid(),
        default);

    // ---- it must never take the caller down with it ------------------------------------------

    /// <remarks>
    /// The contract, and the reason this is not just a repository call in the command handler. A
    /// notification is the news about a booking, never part of it — if the table is gone, the
    /// booking still has to be confirmed.
    /// </remarks>
    [Fact]
    public async Task A_failed_write_never_reaches_the_caller()
    {
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DbUpdateException("notifications table is gone"));

        var act = () => Notify(Guid.NewGuid());

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task A_failed_write_is_logged_rather_than_swallowed_silently()
    {
        _db.Setup(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DbUpdateException("notifications table is gone"));

        await Notify(Guid.NewGuid());

        _logger.Verify(
            l => l.Log(
                LogLevel.Error,
                It.IsAny<EventId>(),
                It.IsAny<It.IsAnyType>(),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    // ---- one event, one row per person -------------------------------------------------------

    [Fact]
    public async Task One_recipient_gets_one_row()
    {
        await Notify(Guid.NewGuid());

        _added.Should().HaveCount(1);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    /// <remarks>
    /// Recipient lists are built out of assignments and applications, which can name the same
    /// person twice — a worker holding both an accepted application and the assignment it created.
    /// One cancelled booking is one piece of news.
    /// </remarks>
    [Fact]
    public async Task The_same_person_named_twice_is_told_once()
    {
        var worker = Guid.NewGuid();
        var other = Guid.NewGuid();

        await _sut.NotifyManyAsync(
            [worker, other, worker],
            NotificationKind.JobCancelled,
            "Your job on Saturday was called off",
            string.Empty,
            NotificationTarget.MyJobs,
            Guid.Empty,
            default);

        _added.Should().HaveCount(2);
        _added.Select(n => n.UserId).Should().BeEquivalentTo([worker, other]);
    }

    [Fact]
    public async Task Several_recipients_are_written_in_one_round_trip()
    {
        await _sut.NotifyManyAsync(
            [Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid()],
            NotificationKind.JobCancelled,
            "Your job on Saturday was called off",
            string.Empty,
            NotificationTarget.MyJobs,
            Guid.Empty,
            default);

        _added.Should().HaveCount(3);
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    /// <remarks>
    /// A booking with no crew on it reaches the cancel handler just like any other. Nobody to tell
    /// must cost nothing, not a save of zero rows.
    /// </remarks>
    [Fact]
    public async Task Nobody_to_tell_touches_the_database_at_all()
    {
        await _sut.NotifyManyAsync(
            [],
            NotificationKind.JobCancelled,
            "Your job on Saturday was called off",
            string.Empty,
            NotificationTarget.MyJobs,
            Guid.Empty,
            default);

        _added.Should().BeEmpty();
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task An_empty_recipient_id_is_not_a_recipient()
    {
        await Notify(Guid.Empty);

        _added.Should().BeEmpty();
        _db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- what gets stored --------------------------------------------------------------------

    [Fact]
    public async Task A_new_notification_starts_unread()
    {
        await Notify(Guid.NewGuid());

        _added.Single().ReadAt.Should().BeNull();
        _added.Single().IsUnread.Should().BeTrue();
    }

    [Fact]
    public async Task The_target_and_its_id_are_stored_so_a_tap_can_land_somewhere()
    {
        var bookingId = Guid.NewGuid();

        await _sut.NotifyAsync(
            Guid.NewGuid(),
            NotificationKind.BookingCompleted,
            "Work finished. Rate Boss T?",
            string.Empty,
            NotificationTarget.BookingRating,
            bookingId,
            default);

        var stored = _added.Single();
        stored.Target.Should().Be(NotificationTarget.BookingRating);
        stored.TargetId.Should().Be(bookingId);
    }

    /// <remarks>
    /// A business with an unusually long name must produce a clipped notification, not a
    /// DbUpdateException that the catch above then turns into nobody being told.
    /// </remarks>
    [Fact]
    public async Task Over_long_wording_is_clipped_rather_than_lost()
    {
        await _sut.NotifyAsync(
            Guid.NewGuid(),
            NotificationKind.BookingConfirmed,
            new string('t', 400),
            new string('b', 900),
            NotificationTarget.Booking,
            Guid.NewGuid(),
            default);

        var stored = _added.Single();
        stored.Title.Should().HaveLength(200).And.EndWith("…");
        stored.Body.Should().HaveLength(500).And.EndWith("…");
    }
}
