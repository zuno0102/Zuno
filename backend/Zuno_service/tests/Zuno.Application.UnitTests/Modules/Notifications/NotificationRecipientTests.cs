using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Notifications;

/// <summary>
/// Who each notification reaches, and who it must not.
/// </summary>
/// <remarks>
/// <b>Nobody is told about their own action.</b> It is the rule that decides whether this feature is
/// useful or noise: a business owner who gets "you confirmed a booking" learns nothing and stops
/// reading the next one, which is the one about a worker dropping out.
///
/// The two events that inform two different people are the ones worth pinning down, because they
/// are where the rule is easiest to break.
/// </remarks>
public class NotificationRecipientTests
{
    private readonly Mock<INotificationSender> _notifications = new();
    private readonly Mock<IDateTimeProvider> _clock = new();

    private readonly List<(Guid UserId, NotificationKind Kind, NotificationTarget Target, string Title)> _sent = [];

    private readonly Guid _customerUserId = Guid.NewGuid();
    private readonly Guid _businessUserId = Guid.NewGuid();
    private readonly Guid _workerUserId = Guid.NewGuid();
    private readonly Guid _bookingId = Guid.NewGuid();

    private static readonly DateTimeOffset Now = new(2025, 11, 12, 9, 30, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Saturday = new(2025, 11, 15, 9, 30, 0, TimeSpan.Zero);

    public NotificationRecipientTests()
    {
        _clock.Setup(c => c.UtcNow).Returns(Now);

        _notifications
            .Setup(n => n.NotifyAsync(
                It.IsAny<Guid>(),
                It.IsAny<NotificationKind>(),
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<NotificationTarget>(),
                It.IsAny<Guid>(),
                It.IsAny<CancellationToken>()))
            .Callback<Guid, NotificationKind, string, string, NotificationTarget, Guid, CancellationToken>(
                (userId, kind, title, _, target, _, _) => _sent.Add((userId, kind, target, title)))
            .Returns(Task.CompletedTask);

        _notifications
            .Setup(n => n.NotifyManyAsync(
                It.IsAny<IEnumerable<Guid>>(),
                It.IsAny<NotificationKind>(),
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<NotificationTarget>(),
                It.IsAny<Guid>(),
                It.IsAny<CancellationToken>()))
            .Callback<IEnumerable<Guid>, NotificationKind, string, string, NotificationTarget, Guid, CancellationToken>(
                (userIds, kind, title, _, target, _, _) =>
                {
                    foreach (var userId in userIds)
                    {
                        _sent.Add((userId, kind, target, title));
                    }
                })
            .Returns(Task.CompletedTask);
    }

    // ---- one assignment, two people told -----------------------------------------------------

    private Task HandleCrewAssigned() =>
        new BookingCrewAssignedNotificationHandler(_notifications.Object, _clock.Object)
            .Handle(
                new BookingCrewAssignedEvent(
                    _bookingId,
                    _customerUserId,
                    _workerUserId,
                    "Boss T",
                    "Ravi Kumar",
                    CrewCount: 3,
                    Saturday),
                default);

    [Fact]
    public async Task Assigning_a_worker_tells_the_customer_and_the_worker_and_nobody_else()
    {
        await HandleCrewAssigned();

        _sent.Select(s => s.UserId).Should().BeEquivalentTo([_customerUserId, _workerUserId]);
        _sent.Should().NotContain(s => s.UserId == _businessUserId);
    }

    [Fact]
    public async Task The_customer_hears_about_the_crew_and_the_worker_hears_about_a_job()
    {
        await HandleCrewAssigned();

        var toCustomer = _sent.Single(s => s.UserId == _customerUserId);
        var toWorker = _sent.Single(s => s.UserId == _workerUserId);

        toCustomer.Kind.Should().Be(NotificationKind.BookingCrewAssigned);
        toCustomer.Title.Should().Be("Your crew is set for Saturday");

        // Deliberately an ask, not an announcement: their row stays pending until they answer.
        toWorker.Kind.Should().Be(NotificationKind.JobAssignment);
        toWorker.Title.Should().Be("You're on a job on Saturday");
    }

    [Fact]
    public async Task A_crew_of_one_is_not_described_as_one_people()
    {
        await new BookingCrewAssignedNotificationHandler(_notifications.Object, _clock.Object)
            .Handle(
                new BookingCrewAssignedEvent(
                    _bookingId, _customerUserId, _workerUserId, "Boss T", "Ravi Kumar", 1, Saturday),
                default);

        _notifications.Verify(
            n => n.NotifyAsync(
                _customerUserId,
                NotificationKind.BookingCrewAssigned,
                It.IsAny<string>(),
                "Boss T has one person on your job.",
                It.IsAny<NotificationTarget>(),
                It.IsAny<Guid>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    // ---- a cancellation, told to whoever did not do it ----------------------------------------

    private Task HandleCancelled(bool byCustomer, params Guid[] workers) =>
        new BookingCancelledNotificationHandler(_notifications.Object, _clock.Object)
            .Handle(
                new BookingCancelledEvent(
                    _bookingId,
                    byCustomer,
                    _customerUserId,
                    _businessUserId,
                    workers,
                    "Boss T",
                    "Asha Rao",
                    Saturday),
                default);

    [Fact]
    public async Task When_the_customer_cancels_the_business_is_told_and_the_customer_is_not()
    {
        await HandleCancelled(byCustomer: true);

        _sent.Select(s => s.UserId).Should().BeEquivalentTo([_businessUserId]);
        _sent.Single().Kind.Should().Be(NotificationKind.BookingCancelledByCustomer);
        _sent.Single().Title.Should().Be("Asha Rao cancelled their booking");
    }

    [Fact]
    public async Task When_the_business_cancels_the_customer_is_told_and_the_business_is_not()
    {
        await HandleCancelled(byCustomer: false);

        _sent.Select(s => s.UserId).Should().BeEquivalentTo([_customerUserId]);
        _sent.Single().Kind.Should().Be(NotificationKind.BookingCancelledByBusiness);
        _sent.Single().Title.Should().Be("Boss T cancelled your booking");
    }

    /// <remarks>
    /// The most expensive silence in this app: a worker who is not told travels to a job that is
    /// not happening. They are told whichever side called it off.
    /// </remarks>
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Every_worker_on_a_cancelled_job_is_told_whoever_cancelled_it(bool byCustomer)
    {
        var secondWorker = Guid.NewGuid();

        await HandleCancelled(byCustomer, _workerUserId, secondWorker);

        var toWorkers = _sent.Where(s => s.Kind == NotificationKind.JobCancelled).ToList();

        toWorkers.Select(s => s.UserId).Should().BeEquivalentTo([_workerUserId, secondWorker]);
        toWorkers.Should().OnlyContain(s => s.Title == "Your job on Saturday was called off");
    }

    /// <remarks>
    /// A cancelled job has nothing left to do on it, so the workers are pointed at the rest of
    /// their week rather than at a dead booking.
    /// </remarks>
    [Fact]
    public async Task A_cancelled_job_sends_its_workers_to_my_jobs_not_to_the_booking()
    {
        await HandleCancelled(byCustomer: true, _workerUserId);

        _sent.Single(s => s.UserId == _workerUserId)
            .Target.Should().Be(NotificationTarget.MyJobs);
    }

    // ---- the rating is an ask, and it opens the sheet -----------------------------------------

    [Fact]
    public async Task A_finished_job_asks_the_customer_to_rate_and_opens_the_rating()
    {
        await new BookingCompletedNotificationHandler(_notifications.Object)
            .Handle(
                new BookingCompletedEvent(_bookingId, _customerUserId, "asha@example.com", "Boss T"),
                default);

        var sent = _sent.Single();
        sent.UserId.Should().Be(_customerUserId);
        sent.Title.Should().Be("Work finished. Rate Boss T?");
        sent.Target.Should().Be(NotificationTarget.BookingRating);
    }

    // ---- a worker answering tells the business, and says which answer -------------------------

    [Theory]
    [InlineData(true, "Ravi Kumar accepted the job on Saturday")]
    [InlineData(false, "Ravi Kumar turned down the job on Saturday")]
    public async Task The_business_is_told_how_a_worker_answered(bool accepted, string expectedTitle)
    {
        await new BookingAssignmentAnsweredNotificationHandler(_notifications.Object, _clock.Object)
            .Handle(
                new BookingAssignmentAnsweredEvent(
                    _bookingId, _businessUserId, "Ravi Kumar", accepted, Saturday),
                default);

        var sent = _sent.Single();
        sent.UserId.Should().Be(_businessUserId);
        sent.Title.Should().Be(expectedTitle);
    }

    // ---- a rating opens the business's own standing, not the finished order -------------------

    [Fact]
    public async Task One_star_is_not_reported_as_one_stars()
    {
        await new BookingRatedNotificationHandler(_notifications.Object)
            .Handle(new BookingRatedEvent(_bookingId, _businessUserId, 1), default);

        _sent.Single().Title.Should().Be("You were rated 1 star");
    }

    [Fact]
    public async Task A_rating_opens_the_profile_because_it_cannot_be_answered()
    {
        await new BookingRatedNotificationHandler(_notifications.Object)
            .Handle(new BookingRatedEvent(_bookingId, _businessUserId, 5), default);

        var sent = _sent.Single();
        sent.Title.Should().Be("You were rated 5 stars");
        sent.Target.Should().Be(NotificationTarget.Profile);
    }
}
