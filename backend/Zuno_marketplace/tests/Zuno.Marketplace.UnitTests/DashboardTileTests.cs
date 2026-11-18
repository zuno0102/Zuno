using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>
/// The Marketplace home tiles in four groups: Products (Live posts across the Marketplace, Inactive,
/// Product stock), B2B (Live, B2B stock), Food (Live, Food left) and Ads (Live, Expired).
/// </summary>
public class DashboardTileTests
{
    [Fact]
    public async Task TheTiles_CountEachGroup_AndLivePostsIsTheWholeMarketplace()
    {
        using var test = new TestMarketplace();
        var free = await test.Db.Plans.SingleAsync(p => p.IsDefault);
        free.MaxActivePosts = 20;
        await test.Db.SaveChangesAsync();

        // A product with its main colour and three others: 4 items.
        await test.SaveHandlers.Handle(new CreateMarketplacePostCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Products,
            SubCategoryId = MarketplaceCatalogSeedData.SubId(3, 1),
            Title = "Silk saree",
            Price = 2_400m,
            Condition = "New",
            Quantity = 5,
            DistrictId = TestMarketplace.Kanyakumari,
            Attributes = new(),
            Variants =
            [
                new() { Colour = "Red", Price = 2_400m, Stock = 5 },
                new() { Colour = "Green", Price = 2_400m, Stock = 3 },
                new() { Colour = "Blue", Price = 2_400m, Stock = 3 },
                new() { Colour = "Yellow", Price = 2_400m, Stock = 3 },
            ],
        }, default);
        await test.SaveHandlers.Handle(TestMarketplace.Bananas(), default);
        await test.SaveHandlers.Handle(TestMarketplace.Bananas(c => c.Title = "Cabbage"), default);
        await test.SaveHandlers.Handle(test.Biryani(), default);
        await test.SaveHandlers.Handle(test.Biryani(c => { c.Title = "Chicken biryani"; c.Quantity = 5; }), default);
        await test.SaveHandlers.Handle(test.AadiSale(), default);
        // Over: a food offer and an advert whose time has passed.
        var expiredFood = test.Seed(p =>
        {
            p.CategoryId = MarketplaceCatalogSeedData.NearbyFood;
            p.SubCategoryId = MarketplaceCatalogSeedData.SubId(5, 1);
            p.Kind = MarketplacePostKind.FoodOffer;
            p.Title = "Yesterday's meals";
            p.Quantity = 7;
            p.StartsAt = test.Now.AddDays(-1);
            p.EndsAt = test.Now.AddHours(-1);
        });
        test.Seed(p =>
        {
            p.CategoryId = MarketplaceCatalogSeedData.Advertisements;
            p.SubCategoryId = MarketplaceCatalogSeedData.SubId(6, 1);
            p.Kind = MarketplacePostKind.Advertisement;
            p.Title = "Old sale";
            p.StartsAt = test.Now.AddDays(-10);
            p.EndsAt = test.Now.AddDays(-1);
        });

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);

        summary.LiveItems.Should().Be(9, "the saree's 4, two B2B lots, two food offers and one advert");
        (summary.LiveWholesale, summary.LiveFood, summary.LiveAds).Should().Be((2, 2, 1));
        summary.FoodPortionsLeft.Should().Be(25, "20 + 5 portions in the offers running now, not the expired 7");
        (summary.ExpiredFood, summary.ExpiredAds).Should().Be((1, 1));
        summary.Inactive.Should().Be(1, "the expired food offer; the expired advert has its own tile");

        var inactive = await test.QueryHandlers.Handle(new GetMyMarketplacePostsQuery { Inactive = true }, default);
        inactive.Items.Select(p => p.Id).Should().Equal(expiredFood.Id);
    }

    [Fact]
    public async Task TheTiles_AreZero_ForABusinessWithNoPosts()
    {
        using var test = new TestMarketplace();

        var summary = await test.QueryHandlers.Handle(new GetMyMarketplaceSummaryQuery(), default);

        (summary.LiveItems, summary.LiveWholesale, summary.LiveFood, summary.LiveAds,
            summary.FoodPortionsLeft, summary.ExpiredFood, summary.ExpiredAds, summary.Inactive)
            .Should().Be((0, 0, 0, 0, 0, 0, 0, 0));
    }
}
