using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Commands.CompleteHiringPostWork;
using Zuno.Application.Modules.HiringPost.Commands.SetHiringPostApplicationRole;
using Zuno.Application.Modules.HiringPost.Commands.StartHiringPostWork;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// Roles on a business's own events, as on an order: Supervisor, Lead or Support, set by the owner
/// on workers who accepted, and the Lead can start and finish that job's work.
/// </summary>
public class OwnEventRoleTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);

    // ---- Builders ----------------------------------------------------------------------------

    private static HiringPost OwnEvent(DateTimeOffset? start = null, Guid? bookingId = null) => new()
    {
        Id = Guid.NewGuid(),
        BusinessOwnerProfileId = Guid.NewGuid(),
        BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "apples business" },
        BookingId = bookingId,
        Title = "Wedding catering",
        EventDate = start ?? Now.AddHours(-1),
        DurationMinutes = 240,
        WorkersNeeded = 3,
        SalaryAmount = 700m,
    };

    private static HiringPostApplication Worker(
        HiringPost post,
        string? role = null,
        HiringPostApplicationStatus status = HiringPostApplicationStatus.Accepted)
    {
        var userId = Guid.NewGuid();
        var application = new HiringPostApplication
        {
            Id = Guid.NewGuid(),
            HiringPostId = post.Id,
            HiringPost = post,
            WorkerProfileId = Guid.NewGuid(),
            WorkerProfile = new WorkerProfile
            {
                UserId = userId,
                User = new User { Id = userId, FirstName = "apple", LastName = "one", PhoneNumber = "9000000001" },
            },
            ApplicationStatus = status,
            AgreedSalaryAmount = 700m,
            Role = role,
        };
        post.Applications.Add(application);
        return application;
    }

    private static Guid UserOf(HiringPostApplication application) => application.WorkerProfile.UserId;

    private static BusinessOwnerProfile OwnerOf(HiringPost post) =>
        new() { Id = post.BusinessOwnerProfileId, UserId = Guid.NewGuid() };

    // ---- The rule ----------------------------------------------------------------------------

    [Fact]
    public void HoldsOwnRoles_OwnEventYes_PostForAnOrderNo()
    {
        HiringPostWorkControl.HoldsOwnRoles(OwnEvent()).Should().BeTrue();
        HiringPostWorkControl.HoldsOwnRoles(OwnEvent(bookingId: Guid.NewGuid())).Should().BeFalse();
    }

    [Fact]
    public void CanHoldRoles_UntilTheWorkIsFinished()
    {
        var post = OwnEvent();
        HiringPostWorkControl.CanHoldRoles(post).Should().BeTrue();

        post.WorkStartedAt = Now;
        HiringPostWorkControl.CanHoldRoles(post).Should().BeTrue("a job under way still has someone running it");

        post.WorkCompletedAt = Now;
        HiringPostWorkControl.CanHoldRoles(post).Should().BeFalse();
    }

    [Theory]
    [InlineData("Lead", HiringPostApplicationStatus.Accepted, true)]
    [InlineData("lead", HiringPostApplicationStatus.Accepted, true)]
    [InlineData("Supervisor", HiringPostApplicationStatus.Accepted, false)]
    [InlineData("Support", HiringPostApplicationStatus.Accepted, false)]
    [InlineData(null, HiringPostApplicationStatus.Accepted, false)]
    [InlineData("Lead", HiringPostApplicationStatus.Confirmed, false)]
    [InlineData("Lead", HiringPostApplicationStatus.Declined, false)]
    public void IsLead_OnlyAnAcceptedLead(string? role, HiringPostApplicationStatus status, bool expected)
    {
        var post = OwnEvent();
        var worker = Worker(post, role, status);

        HiringPostWorkControl.IsLead(post, UserOf(worker)).Should().Be(expected);
    }

    [Fact]
    public void IsLead_SomeoneElseOnTheCrew_IsNotTheLead()
    {
        var post = OwnEvent();
        Worker(post, "Lead");
        var other = Worker(post);

        HiringPostWorkControl.IsLead(post, UserOf(other)).Should().BeFalse();
    }

    [Fact]
    public void IsLead_OnAPostForAnOrder_IsNeverGrantedHere()
    {
        // Its roles live on the order, so a role left on the post grants nothing.
        var post = OwnEvent(bookingId: Guid.NewGuid());
        var worker = Worker(post, "Lead");

        HiringPostWorkControl.IsLead(post, UserOf(worker)).Should().BeFalse();
    }

    [Fact]
    public void MayMoveWork_OwnerAndLeadOnly()
    {
        var post = OwnEvent();
        var lead = Worker(post, "Lead");
        var crew = Worker(post);
        var owner = OwnerOf(post);

        HiringPostWorkControl.MayMoveWork(post, owner.UserId, owner.Id).Should().BeTrue();
        HiringPostWorkControl.MayMoveWork(post, UserOf(lead), null).Should().BeTrue();
        HiringPostWorkControl.MayMoveWork(post, UserOf(crew), null).Should().BeFalse();
        HiringPostWorkControl.MayMoveWork(post, Guid.NewGuid(), Guid.NewGuid()).Should().BeFalse("another business");
    }

    [Fact]
    public void WorkerViewer_OwnerSeesEverything_LeadSeesTheWorkerView()
    {
        var post = OwnEvent();
        var lead = Worker(post, "Lead");
        var owner = OwnerOf(post);

        HiringPostWorkControl.WorkerViewer(post, owner.UserId, owner.Id).Should().BeNull();
        HiringPostWorkControl.WorkerViewer(post, UserOf(lead), null).Should().Be(lead.WorkerProfileId);
    }

    // ---- Setting a role ----------------------------------------------------------------------

    [Theory]
    [InlineData("Lead", "Lead")]
    [InlineData("lead", "Lead")]
    [InlineData("  Supervisor ", "Supervisor")]
    [InlineData("Support", "Support")]
    [InlineData("", null)]
    [InlineData(null, null)]
    public async Task SetRole_ByOwnerOnAcceptedWorker_SavesTheCanonicalRole(string? sent, string? stored)
    {
        var post = OwnEvent();
        var worker = Worker(post, role: "Supervisor");
        var db = Db(post);

        var dto = await SetRoleHandler(OwnerOf(post), db)
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = worker.Id, Role = sent }, CancellationToken.None);

        worker.Role.Should().Be(stored);
        dto.Applications.Single(a => a.Id == worker.Id).Role.Should().Be(stored);
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SetRole_ByAnotherBusiness_IsRefusedAndChangesNothing()
    {
        var post = OwnEvent();
        var worker = Worker(post);
        var db = Db(post);
        var stranger = new BusinessOwnerProfile { Id = Guid.NewGuid(), UserId = Guid.NewGuid() };

        var act = () => SetRoleHandler(stranger, db)
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = worker.Id, Role = "Lead" }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        worker.Role.Should().BeNull();
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SetRole_OnAPostForAnOrder_PointsToTheOrder()
    {
        var post = OwnEvent(bookingId: Guid.NewGuid());
        var worker = Worker(post);

        var act = () => SetRoleHandler(OwnerOf(post), Db(post))
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = worker.Id, Role = "Lead" }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*customer order*");
        worker.Role.Should().BeNull();
    }

    [Fact]
    public async Task SetRole_AfterTheWorkIsFinished_IsRefused()
    {
        var post = OwnEvent();
        post.WorkStartedAt = Now.AddHours(-1);
        post.WorkCompletedAt = Now;
        var worker = Worker(post);

        var act = () => SetRoleHandler(OwnerOf(post), Db(post))
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = worker.Id, Role = "Lead" }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*finished*");
    }

    [Theory]
    [InlineData(HiringPostApplicationStatus.Applied, "*only applied*")]
    [InlineData(HiringPostApplicationStatus.Confirmed, "*not accepted*")]
    [InlineData(HiringPostApplicationStatus.Declined, "*not on this job*")]
    [InlineData(HiringPostApplicationStatus.Rejected, "*not on this job*")]
    public async Task SetRole_WorkerWhoHasNotSaidYes_IsRefused(HiringPostApplicationStatus status, string message)
    {
        var post = OwnEvent();
        var worker = Worker(post, status: status);

        var act = () => SetRoleHandler(OwnerOf(post), Db(post))
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = worker.Id, Role = "Lead" }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage(message);
        worker.Role.Should().BeNull();
    }

    [Fact]
    public async Task SetRole_UnknownApplication_ThrowsNotFound()
    {
        var post = OwnEvent();
        Worker(post);

        var act = () => SetRoleHandler(OwnerOf(post), Db(post))
            .Handle(new SetHiringPostApplicationRoleCommand { ApplicationId = Guid.NewGuid(), Role = "Lead" }, CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    [Theory]
    [InlineData("Lead", true)]
    [InlineData("supervisor", true)]
    [InlineData("", true)]
    [InlineData(null, true)]
    [InlineData("Chef", false)]
    [InlineData("Leed", false)]
    public void SetRoleValidator_OnlyTheThreeRolesOrBlank(string? role, bool valid)
    {
        var result = new SetHiringPostApplicationRoleCommandValidator()
            .Validate(new SetHiringPostApplicationRoleCommand { ApplicationId = Guid.NewGuid(), Role = role });

        result.IsValid.Should().Be(valid);
    }

    [Fact]
    public void SetRoleValidator_MissingApplication_IsRefused()
    {
        new SetHiringPostApplicationRoleCommandValidator()
            .Validate(new SetHiringPostApplicationRoleCommand { Role = "Lead" })
            .IsValid.Should().BeFalse();
    }

    // ---- The Lead starting and finishing -----------------------------------------------------

    [Fact]
    public async Task StartWork_ByTheLead_StartsItAndReturnsTheWorkerView()
    {
        var post = OwnEvent();
        var lead = Worker(post, "Lead");
        Worker(post);

        var dto = await StartHandler(UserOf(lead), business: null, Db(post))
            .Handle(new StartHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        post.WorkStartedAt.Should().Be(Now);
        dto.MyRole.Should().Be("Lead");
        dto.Applications.Should().BeEmpty("a Lead is not handed the rest of the crew's contact details");
    }

    [Fact]
    public async Task StartWork_ByTheOwner_StillWorksWithTheFullCrew()
    {
        var post = OwnEvent();
        Worker(post);
        var owner = OwnerOf(post);

        var dto = await StartHandler(owner.UserId, owner, Db(post))
            .Handle(new StartHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        post.WorkStartedAt.Should().Be(Now);
        dto.Applications.Should().HaveCount(1);
    }

    [Theory]
    [InlineData("Supervisor", HiringPostApplicationStatus.Accepted)]
    [InlineData("Support", HiringPostApplicationStatus.Accepted)]
    [InlineData(null, HiringPostApplicationStatus.Accepted)]
    [InlineData("Lead", HiringPostApplicationStatus.Confirmed)]
    public async Task StartWork_ByAnyoneButTheLead_IsRefused(string? role, HiringPostApplicationStatus status)
    {
        var post = OwnEvent();
        var worker = Worker(post, role, status);
        var db = Db(post);

        var act = () => StartHandler(UserOf(worker), business: null, db)
            .Handle(new StartHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>().WithMessage("*leading this job*");
        post.WorkStartedAt.Should().BeNull();
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task StartWork_ByTheLeadBeforeTheDay_IsRefused()
    {
        var post = OwnEvent(start: Now.AddDays(1));
        var lead = Worker(post, "Lead");

        var act = () => StartHandler(UserOf(lead), business: null, Db(post))
            .Handle(new StartHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*not started yet*");
        post.WorkStartedAt.Should().BeNull();
    }

    [Fact]
    public async Task StartWork_LeadOfAPostForAnOrder_IsRefusedHere()
    {
        var post = OwnEvent(bookingId: Guid.NewGuid());
        var worker = Worker(post, "Lead");

        var act = () => StartHandler(UserOf(worker), business: null, Db(post))
            .Handle(new StartHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task CompleteWork_ByTheLead_FinishesItAndCreditsTheBusiness()
    {
        var post = OwnEvent();
        post.WorkStartedAt = Now.AddHours(-1);
        var lead = Worker(post, "Lead");
        var reputation = new Mock<IBusinessReputationService>();

        var dto = await CompleteHandler(UserOf(lead), business: null, Db(post), reputation)
            .Handle(new CompleteHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        post.WorkCompletedAt.Should().Be(Now);
        dto.MyRole.Should().Be("Lead");
        reputation.Verify(r => r.RecalculateAndSaveAsync(post.BusinessOwnerProfileId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task CompleteWork_ByACrewMemberWithoutLead_IsRefused()
    {
        var post = OwnEvent();
        post.WorkStartedAt = Now.AddHours(-1);
        var worker = Worker(post, "Support");

        var act = () => CompleteHandler(UserOf(worker), business: null, Db(post), new Mock<IBusinessReputationService>())
            .Handle(new CompleteHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        post.WorkCompletedAt.Should().BeNull();
    }

    [Fact]
    public async Task CompleteWork_ByTheLeadBeforeItStarted_IsRefused()
    {
        var post = OwnEvent();
        var lead = Worker(post, "Lead");

        var act = () => CompleteHandler(UserOf(lead), business: null, Db(post), new Mock<IBusinessReputationService>())
            .Handle(new CompleteHiringPostWorkCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("*Start the work*");
    }

    // ---- Helpers -----------------------------------------------------------------------------

    private static Mock<IApplicationDbContext> Db(HiringPost post)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(post));
        db.Setup(d => d.HiringPostApplications).Returns(TestDbSet.From(post.Applications.ToArray()));
        return db;
    }

    private static ICurrentUserService CurrentUser(Guid userId) =>
        Mock.Of<ICurrentUserService>(u => u.UserId == userId);

    private static IDateTimeProvider Clock() => Mock.Of<IDateTimeProvider>(c => c.UtcNow == Now);

    private static Mock<IBusinessOwnerProfileRepository> Businesses(Guid userId, BusinessOwnerProfile? business)
    {
        var businesses = new Mock<IBusinessOwnerProfileRepository>();
        businesses.Setup(r => r.GetByUserIdAsync(userId, It.IsAny<CancellationToken>())).ReturnsAsync(business);
        return businesses;
    }

    private static SetHiringPostApplicationRoleCommandHandler SetRoleHandler(
        BusinessOwnerProfile business,
        Mock<IApplicationDbContext> db) =>
        new(CurrentUser(business.UserId), Businesses(business.UserId, business).Object, db.Object);

    private static StartHiringPostWorkCommandHandler StartHandler(
        Guid userId,
        BusinessOwnerProfile? business,
        Mock<IApplicationDbContext> db) =>
        new(CurrentUser(userId), Clock(), Businesses(userId, business).Object, db.Object);

    private static CompleteHiringPostWorkCommandHandler CompleteHandler(
        Guid userId,
        BusinessOwnerProfile? business,
        Mock<IApplicationDbContext> db,
        Mock<IBusinessReputationService> reputation) =>
        new(CurrentUser(userId), Clock(), Businesses(userId, business).Object, reputation.Object, db.Object);
}
