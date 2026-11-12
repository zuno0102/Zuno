using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Infrastructure.Persistence.Seed;

/// <summary>
/// The starting Marketplace: four main categories — Products, B2B Wholesale, Nearby food and
/// Advertisements — each with its sub-categories and details, the free plan, and the post kinds,
/// statuses and moves. Fixed ids keep it the same in every environment; the super admin adds, renames
/// or switches off rows without a release.
/// </summary>
public static class MarketplaceCatalogSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 11, 11, 0, 0, 0, TimeSpan.Zero);

    /// <summary>The first release's Vehicles category; its posts now live under Products › Vehicles.</summary>
    public static readonly Guid LegacyVehicles = new("d4444444-0000-0000-0000-000000000001");

    /// <summary>The first release's Property category; its posts now live under Products › Property.</summary>
    public static readonly Guid LegacyProperty = new("d4444444-0000-0000-0000-000000000002");

    public static readonly Guid Products = new("d4444444-0000-0000-0000-000000000003");
    public static readonly Guid B2BWholesale = new("d4444444-0000-0000-0000-000000000004");
    public static readonly Guid NearbyFood = new("d4444444-0000-0000-0000-000000000005");
    public static readonly Guid Advertisements = new("d4444444-0000-0000-0000-000000000006");

    public static readonly Guid FreePlan = new("e5555555-0000-0000-0000-000000000001");

    /// <summary>The first releases kept New / Used as a Products detail under this key; it is now the post's own condition.</summary>
    public const string LegacyConditionKey = MarketplacePost.LegacyConditionKey;

    /// <summary>Products › Vehicles: cars and bikes, with their own details.</summary>
    public static Guid Vehicles => SubId(3, 10);

    /// <summary>Products › Property: land, houses, flats, with their own details.</summary>
    public static Guid Property => SubId(3, 11);

    public static MarketplaceCategory[] Categories =>
    [
        Category(LegacyVehicles, "Vehicles", null, null, "vehicles", "car", MarketplacePostKind.Listing, MarketplaceTradeMode.RetailOnly, 90, isActive: false),
        Category(LegacyProperty, "Property", null, null, "property", "home", MarketplacePostKind.Listing, MarketplaceTradeMode.RetailOnly, 91, isActive: false),
        Category(Products, "Products", "Products", "Sarees, shirts, toys, mobiles, vehicles, property", "products", "shopping_bag_outlined", MarketplacePostKind.Listing, MarketplaceTradeMode.RetailOnly, 1, tracksStock: true),
        Category(B2BWholesale, "B2B Wholesale", "B2B", "Banana, pineapple, coconut, chicken — in bulk for dealers", "b2b-wholesale", "agriculture_outlined", MarketplacePostKind.Listing, MarketplaceTradeMode.WholesaleOnly, 2),
        Category(NearbyFood, "Nearby food", "Food", "Last-minute offers: biryani, pizza, burgers — no waste", "nearby-food", "restaurant_outlined", MarketplacePostKind.FoodOffer, MarketplaceTradeMode.RetailOnly, 3),
        Category(Advertisements, "Advertisements", "Ads", "Aadi sale, tournaments, shop and brand openings", "advertisements", "campaign_outlined", MarketplacePostKind.Advertisement, MarketplaceTradeMode.RetailOnly, 4),
    ];

    /// <remarks>Ids encode category and order (<c>c7777777-0000-0000-00cc-0000000000oo</c>), so a new row never collides.</remarks>
    public static MarketplaceSubCategory[] SubCategories =>
    [
        .. Subs(3, Products, "Sarees", "Clothing", "Footwear", "Toys", "Mobiles & electronics", "Home & kitchen", "Furniture", "Beauty", "Books & stationery", "Vehicles", "Property", "Other"),
        .. Subs(4, B2BWholesale, "Fruits", "Vegetables", "Coconut", "Chicken & meat", "Fish", "Grains & pulses", "Spices", "Dairy", "Other"),
        .. Subs(5, NearbyFood, "Biryani & meals", "Pizza & burgers", "Sandwiches & snacks", "Bakery & sweets", "Tea & juice", "Other"),
        .. Subs(6, Advertisements, "Sale & offers", "Cricket tournament", "Football tournament", "Shop opening", "New brand opening", "Events & celebrations", "Other"),
    ];

    /// <remarks>
    /// Ids encode the first release's category and order (<c>f6666666-0000-0000-00cc-0000000000oo</c>)
    /// and never change: the Vehicles and Property details kept their ids when they moved under Products.
    /// </remarks>
    public static MarketplaceCategoryField[] Fields =>
    [
        Field(1, 1, Products, Vehicles, "brand", "Brand", MarketplaceFieldType.Text, required: true),
        Field(1, 2, Products, Vehicles, "model_year", "Model year", MarketplaceFieldType.Number, required: true),
        Field(1, 3, Products, Vehicles, "km_driven", "KM driven", MarketplaceFieldType.Number, required: true, unit: "km"),
        Field(1, 4, Products, Vehicles, "fuel", "Fuel", MarketplaceFieldType.Select, required: true, options: ["Petrol", "Diesel", "CNG", "Electric"]),
        Field(1, 5, Products, Vehicles, "owners", "Owners", MarketplaceFieldType.Number),

        Field(2, 1, Products, Property, "property_type", "Property type", MarketplaceFieldType.Select, required: true, options: ["Land", "House", "Flat", "Shop / commercial"]),
        Field(2, 2, Products, Property, "deal", "For", MarketplaceFieldType.Select, required: true, options: ["Sale", "Rent", "Lease"]),
        Field(2, 3, Products, Property, "area", "Area", MarketplaceFieldType.Number, required: true, unit: "cents"),
        Field(2, 4, Products, Property, "bedrooms", "Bedrooms", MarketplaceFieldType.Number),

        Field(3, 1, Products, null, LegacyConditionKey, "Condition", MarketplaceFieldType.Select, options: ["New", "Used"], isActive: false),
        Field(3, 2, Products, null, "brand", "Brand", MarketplaceFieldType.Text, isActive: false),

        // Switched off: a product asks only its basic fields; the business adds any other detail itself
        // ("More details"). The super admin can switch one back on.
        Field(3, 3, Products, SubId(3, 1), "fabric", "Fabric", MarketplaceFieldType.Select, options: ["Silk", "Cotton", "Georgette", "Chiffon", "Crepe", "Other"], isActive: false),
        Field(3, 4, Products, SubId(3, 2), "fabric", "Fabric", MarketplaceFieldType.Select, options: ["Cotton", "Polyester", "Linen", "Denim", "Wool", "Other"], isActive: false),
        Field(3, 5, Products, SubId(3, 2), "for", "For", MarketplaceFieldType.Select, options: ["Men", "Women", "Kids", "Unisex"], isActive: false),
        Field(3, 6, Products, SubId(3, 3), "material", "Material", MarketplaceFieldType.Select, options: ["Genuine leather", "Synthetic leather", "Canvas", "Rubber", "Other"], isActive: false),
        Field(3, 7, Products, SubId(3, 3), "for", "For", MarketplaceFieldType.Select, options: ["Men", "Women", "Kids", "Unisex"], isActive: false),
        Field(3, 8, Products, SubId(3, 5), "brand", "Brand", MarketplaceFieldType.Text, isActive: false),
        Field(3, 9, Products, SubId(3, 7), "material", "Material", MarketplaceFieldType.Select, options: ["Wood", "Metal", "Plastic", "Glass", "Other"], isActive: false),

        Field(4, 1, B2BWholesale, null, "produce_type", "Produce", MarketplaceFieldType.Select, options: ["Vegetables", "Fruits", "Grains", "Coconut", "Spices", "Dairy", "Other"], isActive: false),
        Field(4, 2, B2BWholesale, null, "organic", "Organic", MarketplaceFieldType.Select, options: ["Yes", "No"]),

        Field(5, 1, NearbyFood, null, "food_type", "Food type", MarketplaceFieldType.Select, required: true, options: ["Veg", "Non-veg"]),

        Field(6, 1, Advertisements, null, "ad_type", "Type", MarketplaceFieldType.Select, options: ["Sale / offer", "Sports tournament", "Event", "Shop opening"], isActive: false),
    ];

    public static MarketplacePlan[] Plans =>
    [
        new()
        {
            Id = FreePlan,
            Code = "free",
            Name = "Free",
            Price = 0m,
            MaxActivePosts = 1,
            DurationDays = null,
            IsDefault = true,
            IsActive = true,
            DisplayOrder = 1,
            CreatedDate = SeedDate,
        },
    ];

    public static MarketplaceTradeModeOption[] TradeModes =>
    [
        new() { Code = MarketplaceTradeMode.RetailOnly, Name = "Retail only", Detail = "One at a time to customers", DisplayOrder = 1 },
        new() { Code = MarketplaceTradeMode.WholesaleOnly, Name = "Wholesale only (B2B)", Detail = "Bulk to businesses: price per unit and a smallest order", DisplayOrder = 2 },
        new() { Code = MarketplaceTradeMode.Either, Name = "Either", Detail = "The business chooses on each post", DisplayOrder = 3 },
    ];

    public static MarketplacePostKindOption[] Kinds =>
    [
        new() { Code = MarketplacePostKind.Listing, Name = "Listing", DisplayOrder = 1 },
        new() { Code = MarketplacePostKind.FoodOffer, Name = "Food offer", DisplayOrder = 2 },
        new() { Code = MarketplacePostKind.Advertisement, Name = "Advertisement", DisplayOrder = 3 },
    ];

    public static MarketplacePostStatusOption[] Statuses =>
    [
        new() { Code = MarketplacePostStatus.Active, Name = "Active", Tone = "success", DisplayOrder = 1 },
        new() { Code = MarketplacePostStatus.Paused, Name = "Paused", Tone = "waiting", DisplayOrder = 2 },
        new() { Code = MarketplacePostStatus.Expired, Name = "Expired", Tone = "danger", DisplayOrder = 3 },
        new() { Code = MarketplacePostStatus.Closed, Name = "Closed", Tone = "progress", DisplayOrder = 4 },
        new() { Code = MarketplacePostStatus.Sold, Name = "Sold", Tone = "success", DisplayOrder = 5 },
    ];

    public static MarketplaceItemConditionOption[] ItemConditions =>
    [
        new() { Code = MarketplaceItemCondition.New, Name = "New", Detail = "Brand new — keep a stock count", DisplayOrder = 1 },
        new() { Code = MarketplaceItemCondition.Used, Name = "Used", Detail = "One piece — mark it sold when it goes", DisplayOrder = 2 },
    ];

    public static MarketplacePostTransition[] Transitions =>
    [
        new() { FromStatus = MarketplacePostStatus.Active, ToStatus = MarketplacePostStatus.Paused, ActionName = "Pause", DisplayOrder = 1 },
        new() { FromStatus = MarketplacePostStatus.Paused, ToStatus = MarketplacePostStatus.Active, ActionName = "Put up again", DisplayOrder = 2 },
        new() { FromStatus = MarketplacePostStatus.Active, ToStatus = MarketplacePostStatus.Closed, ActionName = "Close", NeedsConfirm = true, DisplayOrder = 3 },
        new() { FromStatus = MarketplacePostStatus.Paused, ToStatus = MarketplacePostStatus.Closed, ActionName = "Close", NeedsConfirm = true, DisplayOrder = 4 },
        new() { FromStatus = MarketplacePostStatus.Active, ToStatus = MarketplacePostStatus.Sold, ActionName = "Mark as sold", NeedsConfirm = true, Condition = MarketplaceItemCondition.Used, DisplayOrder = 5 },
        new() { FromStatus = MarketplacePostStatus.Paused, ToStatus = MarketplacePostStatus.Sold, ActionName = "Mark as sold", NeedsConfirm = true, Condition = MarketplaceItemCondition.Used, DisplayOrder = 6 },
    ];

    /// <summary>The fixed id of sub-category <paramref name="order"/> under the first release's category number.</summary>
    public static Guid SubId(int category, int order) => new($"c7777777-0000-0000-00{category:D2}-{order:D12}");

    private static MarketplaceCategory Category(
        Guid id,
        string name,
        string? shortName,
        string? description,
        string slug,
        string icon,
        MarketplacePostKind kind,
        MarketplaceTradeMode tradeMode,
        short order,
        bool tracksStock = false,
        bool isActive = true) =>
        new()
        {
            Id = id,
            Name = name,
            ShortName = shortName,
            Description = description,
            Slug = slug,
            IconName = icon,
            Kind = kind,
            TradeMode = tradeMode,
            TracksStock = tracksStock,
            DisplayOrder = order,
            IsActive = isActive,
            CreatedDate = SeedDate,
        };

    private static IEnumerable<MarketplaceSubCategory> Subs(int category, Guid categoryId, params string[] names) =>
        names.Select((name, i) => new MarketplaceSubCategory
        {
            Id = SubId(category, i + 1),
            CategoryId = categoryId,
            Name = name,
            Slug = Slug(name),
            DisplayOrder = (short)(i + 1),
            IsActive = true,
            CreatedDate = SeedDate,
        });

    private static string Slug(string name) =>
        string.Join('-', name.ToLowerInvariant().Split([' ', '&', '/'], StringSplitOptions.RemoveEmptyEntries));

    private static MarketplaceCategoryField Field(
        int category,
        int order,
        Guid categoryId,
        Guid? subCategoryId,
        string key,
        string label,
        MarketplaceFieldType type,
        bool required = false,
        string? unit = null,
        List<string>? options = null,
        bool isActive = true) =>
        new()
        {
            Id = new Guid($"f6666666-0000-0000-00{category:D2}-{order:D12}"),
            CategoryId = categoryId,
            SubCategoryId = subCategoryId,
            Key = key,
            Label = label,
            FieldType = type,
            IsRequired = required,
            Unit = unit,
            Options = options ?? [],
            DisplayOrder = (short)order,
            IsActive = isActive,
            CreatedDate = SeedDate,
        };
}
