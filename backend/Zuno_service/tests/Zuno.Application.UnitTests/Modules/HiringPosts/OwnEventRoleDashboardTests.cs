using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Worker.Queries.GetWorkerDashboard;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// A worker's role on an own event reaches their home screen, as an order's role always has —
/// so "you're the Lead on 1 job" counts both.
/// </summary>
public class OwnEventRoleDashboardTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Dashboard_UpcomingOwnEvent_CarriesTheWorkersRole()
    {
        var (worker, db) = Arrange(role: "lead", bookingId: null);

        var dto = await Handler(worker, db).Handle(new GetWorkerDashboardQuery(), CancellationToken.None);

        dto.Upcoming.Should().ContainSingle().Which.MyRole.Should().Be("Lead");
    }

    [Fact]
    public async Task Dashboard_PostRaisedForAnOrder_IsNotListedAsAPostJob()
    {
        // It is shown once, through its order, which carries the order's role. A role left on the
        // post itself is never read.
        var (worker, db) = Arrange(role: "Lead", bookingId: Guid.NewGuid());

        var dto = await Handler(worker, db).Handle(new GetWorkerDashboardQuery(), CancellationToken.None);

        dto.Upcoming.Should().BeEmpty();
    }

    [Fact]
    public async Task Dashboard_OwnEventWithoutARole_HasNone()
    {
        var (worker, db) = Arrange(role: null, bookingId: null);

        var dto = await Handler(worker, db).Handle(new GetWorkerDashboardQuery(), CancellationToken.None);

        dto.Upcoming.Should().ContainSingle().Which.MyRole.Should().BeNull();
    }

    private static (WorkerProfile Worker, Mock<IApplicationDbContext> Db) Arrange(string? role, Guid? bookingId)
    {
        var userId = Guid.NewGuid();
        var worker = new WorkerProfile
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            User = new User { Id = userId, FirstName = "apple", LastName = "one" },
        };
        var post = new HiringPost
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            BusinessOwnerProfileId = Guid.NewGuid(),
            BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "apples business" },
            Title = "Wedding catering",
            EventDate = Now.AddDays(2),
            DurationMinutes = 240,
            WorkersNeeded = 3,
            SalaryAmount = 700m,
        };
        var application = new HiringPostApplication
        {
            Id = Guid.NewGuid(),
            HiringPostId = post.Id,
            HiringPost = post,
            WorkerProfileId = worker.Id,
            WorkerProfile = worker,
            ApplicationStatus = HiringPostApplicationStatus.Accepted,
            AgreedSalaryAmount = 700m,
            AgreedSalaryUnit = SalaryUnit.PerEvent,
            Role = role,
        };
        post.Applications.Add(application);

        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.WorkerProfiles).Returns(TestDbSet.From(worker));
        db.Setup(d => d.BookingWorkerAssignments).Returns(TestDbSet.From<BookingWorkerAssignment>());
        db.Setup(d => d.HiringPostApplications).Returns(TestDbSet.From(application));
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(post));
        return (worker, db);
    }

    private static GetWorkerDashboardQueryHandler Handler(WorkerProfile worker, Mock<IApplicationDbContext> db) =>
        new(
            Mock.Of<ICurrentUserService>(u => u.UserId == worker.UserId),
            Mock.Of<IDateTimeProvider>(c => c.UtcNow == Now),
            Mock.Of<IWorkerEarningsService>(),
            new TestPlatformSettings(),
            db.Object);
}
