using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.HiringPost.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// The shared hiring-post loader: posts first, then one query for all their applications. What can be
/// shown without a database is the shape — one applications query however many posts, none when
/// nothing was found, and the caller's order kept. Attaching the applications is EF's fix-up.
/// </summary>
public class HiringPostLoadingTests
{
    private static HiringPost Post(DateTimeOffset eventDate)
    {
        var post = new HiringPost { Id = Guid.NewGuid(), Title = "Wedding catering", EventDate = eventDate };
        post.Applications.Add(new HiringPostApplication { Id = Guid.NewGuid(), HiringPostId = post.Id, HiringPost = post });
        return post;
    }

    private static Mock<IApplicationDbContext> Db(params HiringPost[] posts)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.HiringPosts).Returns(TestDbSet.From(posts));
        db.Setup(d => d.HiringPostApplications)
            .Returns(TestDbSet.From(posts.SelectMany(p => p.Applications).ToArray()));
        return db;
    }

    [Theory]
    [InlineData(HiringPostCrewDetail.Full)]
    [InlineData(HiringPostCrewDetail.ApplicationsOnly)]
    public async Task LoadHiringPostsAsync_ManyPosts_LoadsTheirApplicationsInOneQueryAndKeepsOrder(
        HiringPostCrewDetail detail)
    {
        var later = Post(new DateTimeOffset(2026, 11, 2, 9, 0, 0, TimeSpan.Zero));
        var sooner = Post(new DateTimeOffset(2026, 11, 1, 9, 0, 0, TimeSpan.Zero));
        var db = Db(later, sooner);

        var posts = await db.Object.LoadHiringPostsAsync(
            db.Object.HiringPosts.OrderBy(p => p.EventDate), CancellationToken.None, detail);

        posts.Should().Equal(sooner, later);
        posts.Should().AllSatisfy(p => p.Applications.Should().ContainSingle());
        db.Verify(d => d.HiringPostApplications, Times.Once);
    }

    [Fact]
    public async Task LoadHiringPostsAsync_NoPosts_ReturnsEmptyWithoutQueryingApplications()
    {
        var db = Db();

        var posts = await db.Object.LoadHiringPostsAsync(db.Object.HiringPosts, CancellationToken.None);

        posts.Should().BeEmpty();
        db.Verify(d => d.HiringPostApplications, Times.Never);
    }

    [Fact]
    public async Task LoadHiringPostAsync_Found_ReturnsThePostWithItsApplications()
    {
        var wanted = Post(DateTimeOffset.UnixEpoch);
        var db = Db(Post(DateTimeOffset.UnixEpoch), wanted);

        var post = await db.Object.LoadHiringPostAsync(
            db.Object.HiringPosts.Where(p => p.Id == wanted.Id), CancellationToken.None);

        post.Should().BeSameAs(wanted);
        post!.Applications.Should().ContainSingle();
        db.Verify(d => d.HiringPostApplications, Times.Once);
    }

    [Fact]
    public async Task LoadHiringPostAsync_NotFound_ReturnsNullWithoutQueryingApplications()
    {
        var db = Db(Post(DateTimeOffset.UnixEpoch));

        var post = await db.Object.LoadHiringPostAsync(
            db.Object.HiringPosts.Where(p => p.Id == Guid.NewGuid()), CancellationToken.None);

        post.Should().BeNull();
        db.Verify(d => d.HiringPostApplications, Times.Never);
    }

    [Fact]
    public async Task LoadHiringPostApplicationAsync_Found_ReturnsTheSameInstanceItsPostHolds()
    {
        var post = Post(DateTimeOffset.UnixEpoch);
        var wanted = post.Applications.Single();
        var db = Db(post);

        var application = await db.Object.LoadHiringPostApplicationAsync(
            db.Object.HiringPostApplications.Where(a => a.Id == wanted.Id), CancellationToken.None);

        application.Should().BeSameAs(wanted);
        application!.HiringPost.Applications.Should().ContainSingle().Which.Should().BeSameAs(wanted);
        // Once for the application itself, once for its post's crew.
        db.Verify(d => d.HiringPostApplications, Times.Exactly(2));
    }

    [Fact]
    public async Task LoadHiringPostApplicationAsync_NotFound_ReturnsNullWithoutLoadingACrew()
    {
        var db = Db(Post(DateTimeOffset.UnixEpoch));

        var application = await db.Object.LoadHiringPostApplicationAsync(
            db.Object.HiringPostApplications.Where(a => a.Id == Guid.NewGuid()), CancellationToken.None);

        application.Should().BeNull();
        // Only the lookup that found nothing.
        db.Verify(d => d.HiringPostApplications, Times.Once);
    }
}
