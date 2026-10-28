using FluentAssertions;
using MediatR;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Commands.ConfirmHiringPostApplication;
using Zuno.Application.Modules.HiringPost.Commands.RespondToHiringPostOffer;
using Zuno.Application.Modules.HiringPost.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// Hiring needs both sides to agree, and is complete the moment the second one does:
/// <list type="bullet">
/// <item>The worker applied → the business accepting them hires them. Nothing is left for the worker.</item>
/// <item>The business invited → the worker accepting hires them. Nothing is left for the business.</item>
/// </list>
/// </summary>
public class HireOnSecondYesTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 28, 10, 0, 0, TimeSpan.Zero);

    private readonly BusinessOwnerProfile _business = new() { Id = Guid.NewGuid(), UserId = Guid.NewGuid(), BusinessName = "Nila Caterers" };
    private readonly WorkerProfile _worker;
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly Mock<IBusinessWorkerRepository> _roster = new();
    private readonly Mock<IWorkerScheduleService> _schedule = new();
    private readonly Mock<IPublisher> _publisher = new();
    private readonly List<BookingWorkerAssignment> _assignments = [];

    public HireOnSecondYesTests()
    {
        _worker = new WorkerProfile
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            User = new User { FirstName = "Ravi", LastName = "K" },
        };
        _schedule
            .Setup(s => s.FindConflictAsync(
                It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(),
                It.IsAny<Guid?>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((WorkerScheduleConflict?)null);
    }

    private HiringPostApplication Application(HiringPostApplicationStatus status, global::Zuno.Domain.Entities.Booking? booking = null, int needed = 2)
    {
        var post = new HiringPost
        {
            Id = Guid.NewGuid(),
            BusinessOwnerProfileId = _business.Id,
            BusinessOwnerProfile = _business,
            Title = "Wedding catering",
            EventDate = Now.AddDays(3),
            DurationMinutes = 240,
            WorkersNeeded = needed,
            SalaryAmount = 900,
            BookingId = booking?.Id,
            Booking = booking,
        };
        var application = new HiringPostApplication
        {
            Id = Guid.NewGuid(),
            HiringPostId = post.Id,
            HiringPost = post,
            WorkerProfileId = _worker.Id,
            WorkerProfile = _worker,
            ApplicationStatus = status,
        };
        post.Applications.Add(application);

        var assignments = new Mock<Microsoft.EntityFrameworkCore.DbSet<BookingWorkerAssignment>>();
        assignments.Setup(s => s.Add(It.IsAny<BookingWorkerAssignment>())).Callback<BookingWorkerAssignment>(_assignments.Add);

        _db.Setup(d => d.HiringPostApplications).Returns(TestDbSet.From(application));
        _db.Setup(d => d.WorkerProfiles).Returns(TestDbSet.From(_worker));
        _db.Setup(d => d.Bookings).Returns(booking is null ? TestDbSet.From<global::Zuno.Domain.Entities.Booking>() : TestDbSet.From(booking));
        _db.Setup(d => d.BookingWorkerAssignments).Returns(assignments.Object);
        return application;
    }

    private static global::Zuno.Domain.Entities.Booking Order() => new() { Id = Guid.NewGuid(), BookingStatus = BookingStatus.Confirmed };

    private Task BusinessAccepts(HiringPostApplication application)
    {
        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(_business.UserId);
        var businesses = new Mock<IBusinessOwnerProfileRepository>();
        businesses.Setup(b => b.GetByUserIdAsync(_business.UserId, It.IsAny<CancellationToken>())).ReturnsAsync(_business);

        return new ConfirmHiringPostApplicationCommandHandler(
            currentUser.Object, Clock(), businesses.Object, _roster.Object, _schedule.Object, _db.Object, _publisher.Object)
            .Handle(new ConfirmHiringPostApplicationCommand { ApplicationId = application.Id }, CancellationToken.None);
    }

    private Task WorkerAnswers(HiringPostApplication application, bool accept)
    {
        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(_worker.UserId);

        return new RespondToHiringPostOfferCommandHandler(
            currentUser.Object, Clock(), _roster.Object, _schedule.Object, _db.Object, _publisher.Object)
            .Handle(new RespondToHiringPostOfferCommand { ApplicationId = application.Id, Accept = accept }, CancellationToken.None);
    }

    private static IDateTimeProvider Clock()
    {
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);
        return clock.Object;
    }

    // ---- Scenario 1: the worker applied -------------------------------------------------------

    [Fact]
    public async Task BusinessAcceptsAnApplicant_HiresThemAtOnce()
    {
        var application = Application(HiringPostApplicationStatus.Applied);

        await BusinessAccepts(application);

        application.ApplicationStatus.Should().Be(HiringPostApplicationStatus.Accepted, "the worker already said yes by applying");
        application.AgreedSalaryAmount.Should().Be(900);
        _roster.Verify(r => r.Add(It.Is<BusinessWorker>(w => w.WorkerProfileId == _worker.Id)), Times.Once);
    }

    [Fact]
    public async Task BusinessAcceptsAnApplicant_PutsThemOnTheOrderAsAccepted()
    {
        var application = Application(HiringPostApplicationStatus.Applied, Order());

        await BusinessAccepts(application);

        _assignments.Should().ContainSingle(a =>
            a.WorkerProfileId == _worker.Id && a.AssignmentStatus == BookingWorkerAssignmentStatus.Accepted,
            "Assigned would put the job back in front of the worker to accept a second time");
    }

    [Fact]
    public async Task BusinessAcceptsAnApplicant_TellsThemTheyAreHired()
    {
        var application = Application(HiringPostApplicationStatus.Applied);

        await BusinessAccepts(application);

        _publisher.Verify(p => p.Publish(
            It.Is<HiringPostApplicantHiredEvent>(e => e.WorkerUserId == _worker.UserId),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task AfterBeingHired_TheWorkerHasNothingToAnswer()
    {
        var application = Application(HiringPostApplicationStatus.Applied);
        await BusinessAccepts(application);

        var act = () => WorkerAnswers(application, accept: true);

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task BusinessAccepts_WhenTheLastPlaceIsTaken_IsRefused()
    {
        var application = Application(HiringPostApplicationStatus.Applied, needed: 1);
        application.HiringPost.Applications.Add(new HiringPostApplication
        {
            WorkerProfileId = Guid.NewGuid(),
            WorkerProfile = new WorkerProfile { User = new User() },
            ApplicationStatus = HiringPostApplicationStatus.Accepted,
        });

        var act = () => BusinessAccepts(application);

        await act.Should().ThrowAsync<DomainException>();
        application.ApplicationStatus.Should().Be(HiringPostApplicationStatus.Applied);
        _roster.Verify(r => r.Add(It.IsAny<BusinessWorker>()), Times.Never);
    }

    [Fact]
    public async Task BusinessAccepts_AWorkerBusyElsewhere_IsRefused()
    {
        var application = Application(HiringPostApplicationStatus.Applied);
        _schedule
            .Setup(s => s.FindConflictAsync(
                It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(),
                It.IsAny<Guid?>(), It.IsAny<Guid?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new WorkerScheduleConflict(
                WorkerScheduleConflictKind.Overlap, "Other business", "Another job", Now.AddDays(3), Now.AddDays(3).AddHours(4), 0));

        var act = () => BusinessAccepts(application);

        await act.Should().ThrowAsync<DomainException>();
        application.ApplicationStatus.Should().Be(HiringPostApplicationStatus.Applied);
    }

    [Fact]
    public async Task BusinessCannotAcceptAnInvitationOnTheWorkersBehalf()
    {
        var application = Application(HiringPostApplicationStatus.Confirmed);

        var act = () => BusinessAccepts(application);

        await act.Should().ThrowAsync<DomainException>("an invitation waits on the worker, not the business");
    }

    // ---- Scenario 2: the business invited -----------------------------------------------------

    [Fact]
    public async Task WorkerAcceptsAnInvitation_HiresThemWithNoBusinessStep()
    {
        var application = Application(HiringPostApplicationStatus.Confirmed, Order());

        await WorkerAnswers(application, accept: true);

        application.ApplicationStatus.Should().Be(HiringPostApplicationStatus.Accepted);
        _roster.Verify(r => r.Add(It.Is<BusinessWorker>(w => w.WorkerProfileId == _worker.Id)), Times.Once);
        _assignments.Should().ContainSingle(a => a.AssignmentStatus == BookingWorkerAssignmentStatus.Accepted);
    }

    [Fact]
    public async Task WorkerDeclinesAnInvitation_IsNotHired()
    {
        var application = Application(HiringPostApplicationStatus.Confirmed, Order());
        application.AgreedSalaryAmount = 900;

        await WorkerAnswers(application, accept: false);

        application.ApplicationStatus.Should().Be(HiringPostApplicationStatus.Declined);
        application.AgreedSalaryAmount.Should().BeNull();
        _roster.Verify(r => r.Add(It.IsAny<BusinessWorker>()), Times.Never);
        _assignments.Should().BeEmpty();
    }
}
