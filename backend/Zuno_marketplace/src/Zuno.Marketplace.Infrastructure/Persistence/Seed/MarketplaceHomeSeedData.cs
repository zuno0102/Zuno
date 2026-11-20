using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Infrastructure.Persistence.Seed;

/// <summary>
/// The customer's Marketplace home, top to bottom. Rows, so a heading, an order, a size or a
/// discount band changes without a release. Orders go in tens to leave room between.
/// </summary>
public static class MarketplaceHomeSeedData
{
    public static MarketplaceHomeSection[] Sections =>
    [
        Row(10, "just_in", "Just in", MarketplaceHomeSource.Newest, MarketplaceHomeLayout.Grid, 8),
        Row(20, "banners", string.Empty, MarketplaceHomeSource.Banners, MarketplaceHomeLayout.Banner, 5),
        Row(30, "more_to_explore", "More to explore", MarketplaceHomeSource.Newest, MarketplaceHomeLayout.Grid, 10),
        Row(40, "b2b_lots", "B2B bulk lots", MarketplaceHomeSource.Wholesale, MarketplaceHomeLayout.Strip, 10),
        Row(50, "trending", "Trending now", MarketplaceHomeSource.Trending, MarketplaceHomeLayout.Strip, 7),
        Row(60, "food", "Food offers near you", MarketplaceHomeSource.Food, MarketplaceHomeLayout.Grid, 8),
        Row(70, "recommended", "Recommended for you", MarketplaceHomeSource.Recommended, MarketplaceHomeLayout.Strip, 10),
        Row(80, "wishlist", "From your wishlist", MarketplaceHomeSource.Wishlist, MarketplaceHomeLayout.Strip, 10),

        // Discount bands: each shows the products from its percentage up to the next band's, so a
        // product is in one band only, whatever its exact discount.
        Row(90, "off_70", "Min 70% off", MarketplaceHomeSource.Discount, MarketplaceHomeLayout.Strip, 10, "70"),
        Row(100, "off_50", "Min 50% off", MarketplaceHomeSource.Discount, MarketplaceHomeLayout.Strip, 10, "50"),
        Row(110, "off_30", "Min 30% off", MarketplaceHomeSource.Discount, MarketplaceHomeLayout.Strip, 10, "30"),
        Row(120, "off_10", "Min 10% off", MarketplaceHomeSource.Discount, MarketplaceHomeLayout.Strip, 10, "10"),

        Row(130, "for_men", "For men", MarketplaceHomeSource.Audience, MarketplaceHomeLayout.Strip, 10, "Men,Unisex"),
        Row(140, "for_women", "For women", MarketplaceHomeSource.Audience, MarketplaceHomeLayout.Strip, 10, "Women,Unisex"),
        Row(150, "for_kids", "For kids", MarketplaceHomeSource.Audience, MarketplaceHomeLayout.Strip, 10, "Kids"),
        Row(160, "best_sellers", "Best sellers", MarketplaceHomeSource.BestSellers, MarketplaceHomeLayout.Strip, 10),
        Row(170, "most_reviewed", "Most reviewed", MarketplaceHomeSource.MostReviewed, MarketplaceHomeLayout.Strip, 10),
        Row(180, "all", "All products", MarketplaceHomeSource.All, MarketplaceHomeLayout.Feed, 20),
    ];

    private static MarketplaceHomeSection Row(
        short order,
        string code,
        string title,
        MarketplaceHomeSource source,
        MarketplaceHomeLayout layout,
        short count,
        string? parameter = null) =>
        new()
        {
            Code = code,
            Title = title,
            Source = source,
            Layout = layout,
            ItemCount = count,
            Parameter = parameter,
            DisplayOrder = order,
        };
}
