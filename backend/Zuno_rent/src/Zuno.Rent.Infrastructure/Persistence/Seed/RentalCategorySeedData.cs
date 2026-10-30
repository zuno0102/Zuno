using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Infrastructure.Persistence.Seed;

/// <summary>
/// The starting rent catalogue. Fixed ids keep it the same in every environment; rows can be added,
/// renamed or switched off in the table without a release.
/// </summary>
public static class RentalCategorySeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 29, 0, 0, 0, TimeSpan.Zero);

    public static readonly Guid FurnitureSeating = new("b2222222-0000-0000-0000-000000000001");
    public static readonly Guid TentsShamiana = new("b2222222-0000-0000-0000-000000000002");
    public static readonly Guid SoundLights = new("b2222222-0000-0000-0000-000000000003");
    public static readonly Guid Decoration = new("b2222222-0000-0000-0000-000000000004");
    public static readonly Guid KitchenCatering = new("b2222222-0000-0000-0000-000000000005");
    public static readonly Guid ToolsMachines = new("b2222222-0000-0000-0000-000000000006");
    public static readonly Guid GeneratorsPower = new("b2222222-0000-0000-0000-000000000007");

    public static RentalCategory[] Categories =>
    [
        Category(FurnitureSeating, "Furniture & seating", "furniture-seating", "chair", 1),
        Category(TentsShamiana, "Tents & shamiana", "tents-shamiana", "tent", 2),
        Category(SoundLights, "Sound & lights", "sound-lights", "speaker", 3),
        Category(Decoration, "Decoration", "decoration", "decoration", 4),
        Category(KitchenCatering, "Kitchen & catering equipment", "kitchen-catering", "kitchen", 5),
        Category(ToolsMachines, "Tools & machines", "tools-machines", "tools", 6),
        Category(GeneratorsPower, "Generators & power", "generators-power", "generator", 7),
    ];

    /// <remarks>Ids encode category and order (<c>c3333333-0000-0000-00cc-0000000000oo</c>), so a new row never collides.</remarks>
    public static RentalSubCategory[] SubCategories =>
    [
        Sub(1, 1, FurnitureSeating, "Plastic chairs", "plastic-chairs"),
        Sub(1, 2, FurnitureSeating, "Tables", "tables"),
        Sub(1, 3, FurnitureSeating, "Sofas", "sofas"),
        Sub(1, 4, FurnitureSeating, "Stage", "stage"),

        Sub(2, 1, TentsShamiana, "Shamiana", "shamiana"),
        Sub(2, 2, TentsShamiana, "Pandal", "pandal"),
        Sub(2, 3, TentsShamiana, "Canopy", "canopy"),

        Sub(3, 1, SoundLights, "Speakers", "speakers"),
        Sub(3, 2, SoundLights, "Microphones", "microphones"),
        Sub(3, 3, SoundLights, "Lighting", "lighting"),
        Sub(3, 4, SoundLights, "Projector & screen", "projector-screen"),

        Sub(4, 1, Decoration, "Flower stands", "flower-stands"),
        Sub(4, 2, Decoration, "Backdrops", "backdrops"),
        Sub(4, 3, Decoration, "Carpets", "carpets"),

        Sub(5, 1, KitchenCatering, "Vessels", "vessels"),
        Sub(5, 2, KitchenCatering, "Gas stoves", "gas-stoves"),
        Sub(5, 3, KitchenCatering, "Serving counters", "serving-counters"),

        Sub(6, 1, ToolsMachines, "Cutting machine", "cutting-machine"),
        Sub(6, 2, ToolsMachines, "Drill", "drill"),
        Sub(6, 3, ToolsMachines, "Ladder", "ladder"),
        Sub(6, 4, ToolsMachines, "Pressure washer", "pressure-washer"),

        Sub(7, 1, GeneratorsPower, "Generator", "generator"),
        Sub(7, 2, GeneratorsPower, "Extension & cables", "extension-cables"),
    ];

    public static Guid SubCategoryId(int category, int order) => new($"c3333333-0000-0000-{category:D4}-{order:D12}");

    private static RentalCategory Category(Guid id, string name, string slug, string iconName, short displayOrder) =>
        new()
        {
            Id = id,
            Name = name,
            Slug = slug,
            IconName = iconName,
            DisplayOrder = displayOrder,
            IsActive = true,
            CreatedDate = SeedDate,
        };

    private static RentalSubCategory Sub(int category, short order, Guid categoryId, string name, string slug) =>
        new()
        {
            Id = SubCategoryId(category, order),
            RentalCategoryId = categoryId,
            Name = name,
            Slug = slug,
            DisplayOrder = order,
            IsActive = true,
            CreatedDate = SeedDate,
        };
}
