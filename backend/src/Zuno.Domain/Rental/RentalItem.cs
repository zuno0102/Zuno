using Zuno.Domain.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Domain.Rental;

/// <summary>
/// Something a business rents out: a cutting machine (it has 1), plastic chairs (it has 200, and a
/// family function takes 25, 50 or all of them).
/// </summary>
/// <remarks>
/// <para>
/// Part of the Rent module, separate from services. A rental has no crew and no work to start or
/// finish; it has a quantity, a rate per item, and — once customers can book — times it is out.
/// </para>
/// <para>
/// Holds the owning business's id only, with no navigation into the core model, so the Rent module
/// can never change a business through it. The foreign key is enforced in the database.
/// </para>
/// <para>
/// Ready for bookings: the quantity free for a time window will be <see cref="QuantityOwned"/> less
/// the bookings overlapping it, checked on the server so it can never be overbooked.
/// </para>
/// </remarks>
public class RentalItem : BaseEntity
{
    /// <summary>How a rental may be charged: by the hour, by the day, or one fixed price.</summary>
    /// <remarks>Per person belongs to staffed services and means nothing for an item.</remarks>
    public static readonly IReadOnlyList<PriceType> AllowedPriceTypes =
        [PriceType.Hourly, PriceType.Daily, PriceType.Fixed];

    public Guid BusinessOwnerProfileId { get; set; }

    public Guid RentalCategoryId { get; set; }

    public RentalCategory RentalCategory { get; set; } = null!;

    public Guid? RentalSubCategoryId { get; set; }

    public RentalSubCategory? RentalSubCategory { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public PriceType PriceType { get; set; } = PriceType.Daily;

    /// <summary>The rate for one item: ₹12 per chair per day.</summary>
    public decimal Price { get; set; }

    /// <summary>How many the business has: 1 cutting machine, 200 chairs.</summary>
    public int QuantityOwned { get; private set; } = 1;

    /// <summary>
    /// The business's "available now" switch — off while the machine is being repaired, say.
    /// </summary>
    public bool IsAvailable { get; set; } = true;

    public ICollection<RentalItemMedia> Media { get; set; } = new List<RentalItemMedia>();

    public ICollection<RentalItemDistrict> Districts { get; set; } = new List<RentalItemDistrict>();

    /// <summary>Sets how many the business has. Never fewer than one: a rental of nothing is not one.</summary>
    public void SetQuantityOwned(int quantity)
    {
        if (quantity < 1)
        {
            throw new DomainException("You need at least one of this item to rent it out.");
        }

        QuantityOwned = quantity;
    }

    /// <summary>Sets the rate, refusing a price type an item cannot be charged by.</summary>
    public void SetRate(PriceType priceType, decimal price)
    {
        if (!AllowedPriceTypes.Contains(priceType))
        {
            throw new DomainException("A rent item is charged per hour, per day, or at a fixed price.");
        }

        if (price <= 0)
        {
            throw new DomainException("The rate must be more than zero.");
        }

        PriceType = priceType;
        Price = price;
    }
}
