using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Commands.ApplyToHiringPost;
using Zuno.Application.Modules.HiringPost.Commands.RemoveUnfilledHiringPosts;
using Zuno.Application.Modules.HiringPost.Commands.StopHiringPost;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// Hiring runs until the job is over, not until it starts: a worker can still join one already
/// under way. It ends for good when the business stops hiring, marks the work done, or the
/// scheduled end goes by — and a post that ends with nobody hired is cleared away.
/// </summary>
public class HiringWindowTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 21, 14, 0, 0, TimeSpan.Zero);

    private static HiringPost Post(DateTimeOffset start, int minutes = 240, int needed = 3) => new()
    {
        Id = Guid.NewGuid(),
        BusinessOwnerProfileId = Guid.NewGuid(),
        BusinessOwnerProfile = new BusinessOwnerProfile { BusinessName = "Test" },
        Title = "Wedding catering",
        EventDate = start,
        DurationMinutes = minutes,
        WorkersNeeded = needed,
    };

    private static HiringPost WithAcceptedWorker(HiringPost post)
    {
        post.Applications.Add(new HiringPostApplication
        {
            HiringPostId = post.Id,
            WorkerProfileId = Guid.NewGuid(),
            ApplicationStatus = HiringPostApplicationStatus.Accepted,
        });
        return post;
    }

    // ---- Domain rule -------------------------------------------------------------------------

    [Fact]
    public void IsAcceptingWorkers_WhenWorkUnderWay_ReturnsTrue()
    {
        var post = Post(Now.AddHours(-1));
        post.WorkStartedAt = Now.AddHours(-1);

        post.IsAcceptingWorkers(Now).Should().BeTrue();
    }

    [Theory]
    [InlineData(-239, false)] // one minute before the end: still hiring
    [InlineData(-240, true)]  // exactly at the end: over
    [InlineData(-241, true)]
    public void IsHiringOver_AroundScheduledEnd_ClosesExactlyAtTheEnd(int startedMinutesAgo, bool expected)
    {
        var post = Post(Now.AddMinutes(startedMinutesAgo), minutes: 240);

        post.IsHiringOver(Now).Should().Be(expected);
        Domain.Entities.HiringPost.StillHiringAt(Now).Compile()(post).Should().Be(!expected);
    }

    [Fact]
    public void IsHiringOver_WhenWorkMarkedCompleted_ReturnsTrue()
    {
        var post = Post(Now.AddHours(-1));
        post.WorkCompletedAt = Now;

        post.IsHiringOver(Now).Should().BeTrue();
        Domain.Entities.HiringPost.StillHiringAt(Now).Compile()(post).Should().BeFalse();
    }

    [Fact]
    public void SyncStatusToStaffing_WhenStoppedAndWorkerDropsOut_StaysClosed()
    {
        var post = Post(Now.AddDays(1));
        post.HiringStoppedAt = Now;

        post.SyncStatusToStaffing();

        post.HiringPostStatus.Should().Be(HiringPostStatus.Closed);
        post.IsAcceptingWorkers(Now).Should().BeFalse();
    }

    [Fact]
    public void StillHiringAt_ForLongestAllowedJob_KeepsItOpenUntilItsEnd()
    {
        // The index bound must never cut off a legitimate job still running.
        var post = Post(Now.AddMinutes(-HiringPost.MaxDurationMinutes + 1), minutes: HiringPost.MaxDurationMinutes);

        Domain.Entities.HiringPost.StillHiringAt(Now).Compile()(post).Should().BeTrue();
    }

    [Theory]
    [InlineData(false, false, true)]  // ended, nobody hired, never started → unfilled
    [InlineData(true, false, false)]  // someone accepted → worked, keep
    [InlineData(false, true, false)]  // work was started → keep
    public void UnfilledAndOverAt_ForEndedPost_MatchesOnlyNeverStaffed(bool accepted, bool started, bool expected)
    {
        var post = Post(Now.AddHours(-5), minutes: 60);
        if (accepted)
        {
            WithAcceptedWorker(post);
        }

        if (started)
        {
            post.WorkStartedAt = Now.AddHours(-5);
        }

        HiringPost.UnfilledAndOverAt(Now).Compile()(post).Should().Be(expected);
        HiringPost.WorthKeepingAt(Now).Compile()(post).Should().Be(!expected);
    }

    [Fact]
    public void UnfilledAndOverAt_ForUnfilledPostStillRunning_ReturnsFalse()
    {
        var post = Post(Now.AddMinutes(-30), minutes: 60);

        HiringPost.UnfilledAndOverAt(Now).Compile()(post).Should().BeFalse();
    }

    // ---- Apply -------------------------------------------------------------------------------

    [Theory]
    [InlineData("stopped")]
    [InlineData("completed")]
    [InlineData("ended")]
    public async Task Apply_WhenHiringOver_IsRefused(string reason)
    {
        var post = Post(Now.AddHours(-1));
        switch (reason)
        {
            case "stopped": post.HiringStoppedAt = Now.AddMinutes(-10); break;
            case "completed": post.WorkCompletedAt = Now.AddMinutes(-10); break;
            default: post.EventDate = Now.AddHours(-5); break;
        }

        var worker = new WorkerProfile { Id = Guid.NewGuid(), UserId = Guid.NewGuid() };
        var db = Db(post, worker);
        var handler = new ApplyToHiringPostCommandHandler(
            CurrentUser(worker.UserId), Clock(), db.Object, Mock.Of<MediatR.IPublisher>());

        var act = () => handler.Handle(new ApplyToHiringPostCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>().WithMessage("Hiring for this job has closed.");
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- Stop hiring -------------------------------------------------------------------------

    [Fact]
    public async Task StopHiring_ByOwner_ClosesThePost()
    {
        var post = Post(Now.AddDays(1));
        var db = Db(post);

        await StopHandler(OwnerOf(post), db).Handle(new StopHiringPostCommand { HiringPostId = post.Id }, CancellationToken.None);

        post.HiringStoppedAt.Should().Be(Now);
        post.HiringPostStatus.Should().Be(HiringPostStatus.Closed);
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task StopHiring_ByAnotherBusiness_IsRefusedAndChangesNothing()
    {
        var post = Post(Now.AddDays(1));
        var stranger = new BusinessOwnerProfile { Id = Guid.NewGuid(), UserId = Guid.NewGuid() };
        var db = Db(post);

        var act = () => StopHandler(stranger, db).Handle(new StopHiringPostCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        post.HiringStoppedAt.Should().BeNull();
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task StopHiring_WhenAlreadyStopped_IsRefused()
    {
        var post = Post(Now.AddDays(1));
        post.HiringStoppedAt = Now.AddHours(-1);

        var act = () => StopHandler(OwnerOf(post), Db(post)).Handle(new StopHiringPostCommand { HiringPostId = post.Id }, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>();
        post.HiringStoppedAt.Should().Be(Now.AddHours(-1));
    }

    [Fact]
    public async Task StopHiring_WhenPostDoesNotExist_ThrowsNotFound()
    {
        var post = Post(Now.AddDays(1));

        var act = () => StopHandler(OwnerOf(post), Db(post)).Handle(new StopHiringPostCommand { HiringPostId = Guid.NewGuid() }, CancellationToken.None);

        await act.Should().ThrowAsync<EntityNotFoundException>();
    }

    // ---- Crew size after stopping ------------------------------------------------------------
    //
    // Stopping with 4 of 5 hired turns the job into a job for 4. The place never filled is not
    // shown as missing — not to the business, not to the workers.

    [Fact]
    public async Task StopHiring_WithFourOfFiveHired_ReportsACrewOfFour()
    {
        var post = Post(Now.AddDays(1), needed: 5);
        for (var i = 0; i < 4; i++)
        {
            post.Applications.Add(Hired(post));
        }

        var dto = await StopHandler(OwnerOf(post), Db(post))
            .Handle(new StopHiringPostCommand { HiringPostId = post.Id }, CancellationToken.None);

        dto.WorkersNeeded.Should().Be(4);
        dto.FilledCount.Should().Be(4);
        post.WorkersNeeded.Should().Be(5, "the original target is kept for the record");
    }

    [Fact]
    public void CrewSize_WhileStillHiring_IsTheTarget()
    {
        var post = Post(Now.AddDays(1), needed: 5);
        post.Applications.Add(Hired(post));

        post.CrewSize.Should().Be(5);
    }

    [Theory]
    [InlineData(5, 1, 1)]
    [InlineData(5, 4, 4)]
    [InlineData(4, 4, 4)]
    public void CrewSize_AfterStopping_IsTheHiredCount(int needed, int hired, int expected)
    {
        var post = Post(Now.AddDays(1), needed: needed);
        for (var i = 0; i < hired; i++)
        {
            post.Applications.Add(Hired(post));
        }

        post.HiringStoppedAt = Now;

        post.CrewSize.Should().Be(expected);
    }

    [Fact]
    public void CrewSize_StoppedWithNobodyHired_KeepsTheTarget()
    {
        var post = Post(Now.AddDays(1), needed: 1);
        post.HiringStoppedAt = Now;

        // Not "0 of 0". The app shows such a post as "Nobody was hired".
        post.CrewSize.Should().Be(1);
    }

    [Fact]
    public void CrewSize_StoppedWithOffersStillWaiting_CountsOnlyAccepted()
    {
        var post = Post(Now.AddDays(1), needed: 5);
        post.Applications.Add(Hired(post));
        post.Applications.Add(new HiringPostApplication
        {
            HiringPostId = post.Id,
            WorkerProfileId = Guid.NewGuid(),
            ApplicationStatus = HiringPostApplicationStatus.Confirmed,
        });
        post.HiringStoppedAt = Now;

        post.CrewSize.Should().Be(1);
    }

    private static HiringPostApplication Hired(HiringPost post) => new()
    {
        Id = Guid.NewGuid(),
        HiringPostId = post.Id,
        WorkerProfileId = Guid.NewGuid(),
        WorkerProfile = new WorkerProfile { User = new User { FirstName = "Ravi", LastName = "Kumar" } },
        ApplicationStatus = HiringPostApplicationStatus.Accepted,
        AgreedSalaryAmount = 700m,
    };

    // ---- Cleanup -----------------------------------------------------------------------------

    [Fact]
    public async Task RemoveUnfilled_DeletesOnlyNeverStaffedEndedPosts()
    {
        var unfilled = Post(Now.AddHours(-5), minutes: 60);
        var worked = WithAcceptedWorker(Post(Now.AddHours(-5), minutes: 60));
        var running = Post(Now.AddMinutes(-30), minutes: 60);
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(unfilled, worked, running));

        var removed = await new RemoveUnfilledHiringPostsCommandHandler(Clock(), db.Object)
            .Handle(new RemoveUnfilledHiringPostsCommand { BatchSize = 100 }, CancellationToken.None);

        removed.Should().Be(1);
        unfilled.IsDeleted.Should().BeTrue();
        worked.IsDeleted.Should().BeFalse();
        running.IsDeleted.Should().BeFalse();
    }

    [Fact]
    public async Task RemoveUnfilled_RespectsBatchSize_OldestFirst()
    {
        var oldest = Post(Now.AddDays(-3), minutes: 60);
        var newer = Post(Now.AddDays(-1), minutes: 60);
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(newer, oldest));

        var removed = await new RemoveUnfilledHiringPostsCommandHandler(Clock(), db.Object)
            .Handle(new RemoveUnfilledHiringPostsCommand { BatchSize = 1 }, CancellationToken.None);

        removed.Should().Be(1);
        oldest.IsDeleted.Should().BeTrue();
        newer.IsDeleted.Should().BeFalse();
    }

    [Fact]
    public async Task RemoveUnfilled_WhenNothingToRemove_DoesNotSave()
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(Post(Now.AddDays(1))));

        var removed = await new RemoveUnfilledHiringPostsCommandHandler(Clock(), db.Object)
            .Handle(new RemoveUnfilledHiringPostsCommand { BatchSize = 100 }, CancellationToken.None);

        removed.Should().Be(0);
        db.Verify(d => d.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Never);
    }

    // ---- Helpers -----------------------------------------------------------------------------

    private static BusinessOwnerProfile OwnerOf(HiringPost post) =>
        new() { Id = post.BusinessOwnerProfileId, UserId = Guid.NewGuid() };

    private static StopHiringPostCommandHandler StopHandler(BusinessOwnerProfile business, Mock<IApplicationDbContext> db)
    {
        var businesses = new Mock<IBusinessOwnerProfileRepository>();
        businesses.Setup(r => r.GetByUserIdAsync(business.UserId, It.IsAny<CancellationToken>())).ReturnsAsync(business);
        return new StopHiringPostCommandHandler(CurrentUser(business.UserId), Clock(), businesses.Object, db.Object);
    }

    private static ICurrentUserService CurrentUser(Guid userId) =>
        Mock.Of<ICurrentUserService>(u => u.UserId == userId);

    private static IDateTimeProvider Clock() => Mock.Of<IDateTimeProvider>(c => c.UtcNow == Now);

    private static Mock<IApplicationDbContext> Db(HiringPost post, WorkerProfile? worker = null)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(post));
        db.Setup(d => d.WorkerProfiles).Returns(worker is null ? TestDbSet.From<WorkerProfile>() : TestDbSet.From(worker));
        return db;
    }
}
