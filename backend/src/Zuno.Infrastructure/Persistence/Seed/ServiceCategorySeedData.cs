using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// Baseline service category catalog. Fixed GUIDs keep the seed deterministic across
/// environments; Admin-side category management (add/rename/deactivate) builds on top of these rows.
/// </summary>
public static class ServiceCategorySeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    public static readonly Guid Plumbing = new("a1111111-0000-0000-0000-000000000001");
    public static readonly Guid Electrical = new("a1111111-0000-0000-0000-000000000002");
    public static readonly Guid Cleaning = new("a1111111-0000-0000-0000-000000000003");
    public static readonly Guid Carpentry = new("a1111111-0000-0000-0000-000000000004");
    public static readonly Guid Painting = new("a1111111-0000-0000-0000-000000000005");
    public static readonly Guid ApplianceRepair = new("a1111111-0000-0000-0000-000000000006");
    public static readonly Guid PestControl = new("a1111111-0000-0000-0000-000000000007");
    public static readonly Guid Beauty = new("a1111111-0000-0000-0000-000000000008");

    public static ServiceCategory[] All =>
    [
        Build(Plumbing, "Plumbing", "plumbing", "Leak repairs, pipe fitting, and bathroom fixtures.", 1, "plumbing"),
        Build(Electrical, "Electrical", "electrical", "Wiring, switchboards, and appliance installation.", 2, "electrical"),
        Build(Cleaning, "Cleaning", "cleaning", "Home deep cleaning, sofa and carpet shampooing.", 3, "cleaning"),
        Build(Carpentry, "Carpentry", "carpentry", "Furniture repair, fitting, and custom woodwork.", 4, "carpentry"),
        Build(Painting, "Painting", "painting", "Interior and exterior wall painting.", 5, "painting"),
        Build(ApplianceRepair, "Appliance Repair", "appliance-repair", "AC, refrigerator, and washing machine repair.", 6, "appliance"),
        Build(PestControl, "Pest Control", "pest-control", "General and termite pest control treatments.", 7, "pest-control"),
        Build(Beauty, "Beauty & Wellness", "beauty-wellness", "At-home salon, spa, and grooming services.", 8, "beauty"),
    ];

    /// <param name="iconName">
    /// Which icon the apps draw for this row. Seeded here so the catalogue carries its own
    /// appearance — the customer app used to decide this by matching words in the name, which gave
    /// Carpentry a lorry and anything unrecognised a generic spanner.
    /// </param>
    private static ServiceCategory Build(
        Guid id,
        string name,
        string slug,
        string description,
        short displayOrder,
        string iconName) =>
        new()
        {
            Id = id,
            Name = name,
            Slug = slug,
            Description = description,
            IconName = iconName,
            DisplayOrder = displayOrder,
            IsActive = true,
            CreatedDate = SeedDate,
            IsDeleted = false,
        };
}
