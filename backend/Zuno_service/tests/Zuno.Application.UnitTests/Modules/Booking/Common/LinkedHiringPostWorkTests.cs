using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.Booking.Common;

/// <summary>
/// An order's hiring posts start and finish with the order — the post is what its crew's job
/// screens and pay run read, and paying refuses a post whose work is not marked done.
/// </summary>
public class LinkedHiringPostWorkTests
{
    private static readonly DateTimeOffset Started = new(2026, 10, 20, 9, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Finished = Started.AddHours(6);

    private readonly Guid _orderId = Guid.NewGuid();
    private readonly Mock<IApplicationDbContext> _db = new();

    private void Given(params HiringPost[] posts) =>
        _db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(posts));

    [Fact]
    public async Task MarkCompleted_StampsTheOrdersPosts_AndNoOthers()
    {
        var mine = new HiringPost { BookingId = _orderId, Title = "Crew" };
        var someoneElses = new HiringPost { BookingId = Guid.NewGuid(), Title = "Other" };
        var ownEvent = new HiringPost { BookingId = null, Title = "Own event" };
        Given(mine, someoneElses, ownEvent);

        await LinkedHiringPostWork.MarkCompletedAsync(_db.Object, _orderId, Started, Finished, CancellationToken.None);

        mine.WorkStartedAt.Should().Be(Started);
        mine.WorkCompletedAt.Should().Be(Finished);
        someoneElses.WorkCompletedAt.Should().BeNull();
        ownEvent.WorkCompletedAt.Should().BeNull();
    }

    [Fact]
    public async Task MarkCompleted_KeepsAPostsOwnStartTime()
    {
        var earlier = Started.AddHours(-1);
        var post = new HiringPost { BookingId = _orderId, Title = "Crew", WorkStartedAt = earlier };
        Given(post);

        await LinkedHiringPostWork.MarkCompletedAsync(_db.Object, _orderId, Started, Finished, CancellationToken.None);

        post.WorkStartedAt.Should().Be(earlier);
    }

    [Fact]
    public async Task MarkCompleted_OrderNeverMarkedStarted_UsesTheFinishTime()
    {
        var post = new HiringPost { BookingId = _orderId, Title = "Crew" };
        Given(post);

        await LinkedHiringPostWork.MarkCompletedAsync(_db.Object, _orderId, startedAt: null, Finished, CancellationToken.None);

        post.WorkStartedAt.Should().Be(Finished);
    }

    [Fact]
    public async Task MarkCompleted_AlreadyFinishedPost_IsLeftAsItWas()
    {
        var done = Finished.AddDays(-1);
        var post = new HiringPost { BookingId = _orderId, Title = "Crew", WorkStartedAt = Started, WorkCompletedAt = done };
        Given(post);

        await LinkedHiringPostWork.MarkCompletedAsync(_db.Object, _orderId, Started, Finished, CancellationToken.None);

        post.WorkCompletedAt.Should().Be(done);
    }

    [Fact]
    public async Task MarkStarted_StampsTheOrdersPostsThatHaveNotStarted()
    {
        var waiting = new HiringPost { BookingId = _orderId, Title = "Crew" };
        var other = new HiringPost { BookingId = Guid.NewGuid(), Title = "Other" };
        Given(waiting, other);

        await LinkedHiringPostWork.MarkStartedAsync(_db.Object, _orderId, Started, CancellationToken.None);

        waiting.WorkStartedAt.Should().Be(Started);
        other.WorkStartedAt.Should().BeNull();
    }
}
