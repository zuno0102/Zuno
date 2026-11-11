using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Infrastructure.Persistence.Seed;

/// <summary>
/// The starting Marketplace: six categories with their details, the free plan, and the post kinds,
/// statuses and moves. Fixed ids keep it the same in every environment; the super admin adds, renames
/// or switches off rows without a release.
/// </summary>
public static class MarketplaceCatalogSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 11, 11, 0, 0, 0, TimeSpan.Zero);

    public static readonly Guid Vehicles = new("d4444444-0000-0000-0000-000000000001");
    public static readonly Guid Property = new("d4444444-0000-0000-0000-000000000002");
    public static readonly Guid Products = new("d4444444-0000-0000-0000-000000000003");
    public static readonly Guid FarmWholesale = new("d4444444-0000-0000-0000-000000000004");
    public static readonly Guid FoodOffers = new("d4444444-0000-0000-0000-000000000005");
    public static readonly Guid EventsSales = new("d4444444-0000-0000-0000-000000000006");

    public static readonly Guid FreePlan = new("e5555555-0000-0000-0000-000000000001");

    public static MarketplaceCategory[] Categories =>
    [
        Category(Vehicles, "Vehicles", "vehicles", "car", MarketplacePostKind.Listing, 1),
        Category(Property, "Property", "property", "home", MarketplacePostKind.Listing, 2),
        Category(Products, "Products", "products", "shopping", MarketplacePostKind.Listing, 3),
        Category(FarmWholesale, "Farm & Wholesale", "farm-wholesale", "agriculture", MarketplacePostKind.Listing, 4, allowsWholesale: true),
        Category(FoodOffers, "Food offers", "food-offers", "food", MarketplacePostKind.FoodOffer, 5),
        Category(EventsSales, "Events & Sales", "events-sales", "campaign", MarketplacePostKind.Advertisement, 6),
    ];

    /// <remarks>Ids encode category and order (<c>f6666666-0000-0000-00cc-0000000000oo</c>), so a new row never collides.</remarks>
    public static MarketplaceCategoryField[] Fields =>
    [
        Field(1, 1, Vehicles, "brand", "Brand", MarketplaceFieldType.Text, required: true),
        Field(1, 2, Vehicles, "model_year", "Model year", MarketplaceFieldType.Number, required: true),
        Field(1, 3, Vehicles, "km_driven", "KM driven", MarketplaceFieldType.Number, required: true, unit: "km"),
        Field(1, 4, Vehicles, "fuel", "Fuel", MarketplaceFieldType.Select, required: true, options: ["Petrol", "Diesel", "CNG", "Electric"]),
        Field(1, 5, Vehicles, "owners", "Owners", MarketplaceFieldType.Number),

        Field(2, 1, Property, "property_type", "Property type", MarketplaceFieldType.Select, required: true, options: ["Land", "House", "Flat", "Shop / commercial"]),
        Field(2, 2, Property, "deal", "For", MarketplaceFieldType.Select, required: true, options: ["Sale", "Rent", "Lease"]),
        Field(2, 3, Property, "area", "Area", MarketplaceFieldType.Number, required: true, unit: "cents"),
        Field(2, 4, Property, "bedrooms", "Bedrooms", MarketplaceFieldType.Number),

        Field(3, 1, Products, "condition", "Condition", MarketplaceFieldType.Select, required: true, options: ["New", "Used"]),
        Field(3, 2, Products, "brand", "Brand", MarketplaceFieldType.Text),

        Field(4, 1, FarmWholesale, "produce_type", "Produce", MarketplaceFieldType.Select, required: true, options: ["Vegetables", "Fruits", "Grains", "Coconut", "Spices", "Dairy", "Other"]),
        Field(4, 2, FarmWholesale, "organic", "Organic", MarketplaceFieldType.Select, options: ["Yes", "No"]),

        Field(5, 1, FoodOffers, "food_type", "Food type", MarketplaceFieldType.Select, required: true, options: ["Veg", "Non-veg"]),

        Field(6, 1, EventsSales, "ad_type", "Type", MarketplaceFieldType.Select, required: true, options: ["Sale / offer", "Sports tournament", "Event", "Shop opening"]),
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
    ];

    public static MarketplacePostTransition[] Transitions =>
    [
        new() { FromStatus = MarketplacePostStatus.Active, ToStatus = MarketplacePostStatus.Paused, ActionName = "Pause", DisplayOrder = 1 },
        new() { FromStatus = MarketplacePostStatus.Paused, ToStatus = MarketplacePostStatus.Active, ActionName = "Put up again", DisplayOrder = 2 },
        new() { FromStatus = MarketplacePostStatus.Active, ToStatus = MarketplacePostStatus.Closed, ActionName = "Close (sold / done)", NeedsConfirm = true, DisplayOrder = 3 },
        new() { FromStatus = MarketplacePostStatus.Paused, ToStatus = MarketplacePostStatus.Closed, ActionName = "Close (sold / done)", NeedsConfirm = true, DisplayOrder = 4 },
    ];

    private static MarketplaceCategory Category(
        Guid id, string name, string slug, string icon, MarketplacePostKind kind, short order, bool allowsWholesale = false) =>
        new()
        {
            Id = id,
            Name = name,
            Slug = slug,
            IconName = icon,
            Kind = kind,
            AllowsWholesale = allowsWholesale,
            DisplayOrder = order,
            IsActive = true,
            CreatedDate = SeedDate,
        };

    private static MarketplaceCategoryField Field(
        int category,
        int order,
        Guid categoryId,
        string key,
        string label,
        MarketplaceFieldType type,
        bool required = false,
        string? unit = null,
        List<string>? options = null) =>
        new()
        {
            Id = new Guid($"f6666666-0000-0000-00{category:D2}-{order:D12}"),
            CategoryId = categoryId,
            Key = key,
            Label = label,
            FieldType = type,
            IsRequired = required,
            Unit = unit,
            Options = options ?? [],
            DisplayOrder = (short)order,
            IsActive = true,
            CreatedDate = SeedDate,
        };
}
