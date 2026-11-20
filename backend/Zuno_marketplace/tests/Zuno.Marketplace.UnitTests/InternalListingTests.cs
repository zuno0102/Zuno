using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.UnitTests;

/// <summary>What the Service API reads, pauses and resumes when a business's plan ends or renews.</summary>
public class InternalListingTests
{
    [Fact]
    public async Task Reads_Pauses_And_Resumes_Only_That_Businesses_Live_Posts()
    {
        using var test = new TestMarketplace();
        test.Clock.Current = test.Now.AddMinutes(-10);
        var older = test.Seed(p => p.Title = "Older");
        test.Clock.Current = test.Now.AddMinutes(5);
        var newer = test.Seed(p => p.Title = "Newer");
        test.Seed(p => p.Status = MarketplacePostStatus.Paused);
        test.Seed(p => p.EndsAt = test.Now.AddMinutes(-1));
        var theirs = test.Seed(p => p.OwnerUserId = TestMarketplace.OwnerB);
        var handlers = new InternalListingHandlers(test.Db, test.Clock);

        (await handlers.Handle(new GetLiveListingsQuery(TestMarketplace.OwnerA), default))
            .Select(l => l.Id).Should().Equal([older.Id, newer.Id], "live only, oldest first");

        await handlers.Handle(new SetListingsLiveCommand(TestMarketplace.OwnerA, [newer.Id, theirs.Id], Live: false), default);
        test.Db.ChangeTracker.Clear();
        (await test.Db.Posts.SingleAsync(p => p.Id == newer.Id)).Status.Should().Be(MarketplacePostStatus.Paused);
        (await test.Db.Posts.SingleAsync(p => p.Id == theirs.Id)).Status.Should().Be(MarketplacePostStatus.Active, "not that business's post");

        await handlers.Handle(new SetListingsLiveCommand(TestMarketplace.OwnerA, [newer.Id], Live: true), default);
        test.Db.ChangeTracker.Clear();
        (await test.Db.Posts.SingleAsync(p => p.Id == newer.Id)).Status.Should().Be(MarketplacePostStatus.Active);
    }
}
