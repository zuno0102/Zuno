using System.Globalization;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The sub-categories offered inside each main category — the list a business picks from when
/// adding an item to a service.
/// </summary>
/// <remarks>
/// Deterministic GUIDs, like <see cref="ServiceCategorySeedData"/>: the last group counts the
/// category and the sub-category, so a row keeps its id across every environment and a later
/// addition never renumbers the ones already in use.
/// </remarks>
public static class ServiceSubCategorySeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    /// <summary>Sub-category names per main category, in the order they should be offered.</summary>
    private static readonly (Guid Category, short Index, string[] Names)[] Groups =
    [
        (ServiceCategorySeedData.Plumbing, 1, [
            "Tap & mixer repair",
            "Pipe leak repair",
            "Bathroom fitting",
            "Drainage unclogging",
            "Water tank cleaning",
            "Motor & pump repair",
        ]),
        (ServiceCategorySeedData.Electrical, 2, [
            "Wiring & rewiring",
            "Switchboard & socket",
            "Fan installation",
            "Light & chandelier fitting",
            "Inverter & stabiliser",
            "MCB & fuse repair",
        ]),
        (ServiceCategorySeedData.Cleaning, 3, [
            "Bedroom cleaning",
            "Kitchen cleaning",
            "Bathroom cleaning",
            "Utensils & dishwashing",
            "Sofa & carpet cleaning",
            "Full home deep cleaning",
        ]),
        (ServiceCategorySeedData.Carpentry, 4, [
            "Furniture repair",
            "Door & window work",
            "Wardrobe & storage",
            "Modular kitchen",
            "Bed & cot work",
            "Custom woodwork",
        ]),
        (ServiceCategorySeedData.Painting, 5, [
            "Interior wall painting",
            "Exterior wall painting",
            "Putty & primer work",
            "Texture & stencil",
            "Wood polishing",
            "Waterproofing",
            // Appended, never inserted: position decides the id, so slotting this in beside the
            // other wall work would hand six live rows somebody else's id.
            "Acrylic painting",
        ]),
        (ServiceCategorySeedData.ApplianceRepair, 6, [
            "AC service & repair",
            "Refrigerator repair",
            "Washing machine repair",
            "Microwave & oven repair",
            "Water purifier service",
            "TV & display repair",
        ]),
        (ServiceCategorySeedData.PestControl, 7, [
            "General pest control",
            "Termite treatment",
            "Cockroach control",
            "Bed bug treatment",
            "Rodent control",
            "Mosquito control",
        ]),
        (ServiceCategorySeedData.Beauty, 8, [
            "Hair cut & styling",
            "Facial & clean-up",
            "Waxing & threading",
            "Manicure & pedicure",
            "Bridal makeup",
            "Massage & spa",
        ]),
    ];

    public static ServiceSubCategory[] All =>
    [
        .. Groups.SelectMany(group => group.Names.Select((name, position) => new ServiceSubCategory
        {
            Id = BuildId(group.Index, (short)(position + 1)),
            ServiceCategoryId = group.Category,
            Name = name,
            Slug = Slugify(name),
            DisplayOrder = (short)(position + 1),
            IsActive = true,
            CreatedDate = SeedDate,
            IsDeleted = false,
        })),
    ];

    private static Guid BuildId(short categoryIndex, short position) => new(
        string.Create(
            CultureInfo.InvariantCulture,
            $"a2222222-0000-0000-{categoryIndex:0000}-{position:000000000000}"));

    /// <summary>"Sofa &amp; carpet cleaning" becomes "sofa-carpet-cleaning".</summary>
    private static string Slugify(string name)
    {
        var words = name
            .ToLower(CultureInfo.InvariantCulture)
            .Split([' ', '&', '-', '/'], StringSplitOptions.RemoveEmptyEntries);

        return string.Join('-', words);
    }
}
