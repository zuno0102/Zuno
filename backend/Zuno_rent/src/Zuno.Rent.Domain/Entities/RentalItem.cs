using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// Something a business rents out, and how many of it they have — one cutting machine, or two
/// hundred plastic chairs rented 25 or 50 at a time.
/// </summary>
/// <remarks>
/// Owned by the signed-in user who listed it (<see cref="OwnerUserId"/>, from the shared login), so
/// Rent needs nothing from the Service database. Bookings by time arrive in step 2 and will count
/// against <see cref="QuantityOwned"/>.
/// </remarks>
public class RentalItem : BaseEntity
{
    public Guid OwnerUserId { get; set; }

    public Guid RentalCategoryId { get; set; }

    public RentalCategory RentalCategory { get; set; } = null!;

    public Guid? RentalSubCategoryId { get; set; }

    public RentalSubCategory? RentalSubCategory { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public RentalPriceType PriceType { get; private set; } = RentalPriceType.Daily;

    /// <summary>For one item, per <see cref="PriceType"/>.</summary>
    public decimal Price { get; private set; }

    public int QuantityOwned { get; private set; } = 1;

    /// <summary>Whether an advance is asked, and how it is counted. None: no advance.</summary>
    public RentalAdvanceType AdvanceType { get; private set; } = RentalAdvanceType.None;

    /// <summary>For the whole order or for each piece, per <see cref="AdvanceType"/>; null when none is asked.</summary>
    public decimal? AdvanceAmount { get; private set; }

    /// <summary>Off while the item cannot be rented, e.g. under repair.</summary>
    public bool IsAvailable { get; set; } = true;

    public ICollection<RentalItemMedia> Media { get; set; } = new List<RentalItemMedia>();

    public ICollection<RentalItemDistrict> Districts { get; set; } = new List<RentalItemDistrict>();

    /// <summary>What the business asks every customer renting this item, in display order.</summary>
    public ICollection<RentalItemQuestion> Questions { get; set; } = new List<RentalItemQuestion>();

    /// <summary>
    /// What a customer cancelling is charged, by how long before the start — nearest the start
    /// last. Empty: cancelling is free. Within the category's limit, always.
    /// </summary>
    public List<RentalCancelStep> CancelSteps { get; private set; } = [];

    /// <summary>Sets the cancellation steps, refusing any above <paramref name="limitPercent"/> (the category's limit).</summary>
    /// <summary>How the charge is worked out: steps by time left, or a percent per rental day.</summary>
    public RentalCancelChargeType CancelChargeType { get; private set; } = RentalCancelChargeType.ByTimeLeft;

    /// <summary>For a per-rental-day charge: the percent for each day (or hour) rented, e.g. 1%.</summary>
    public decimal? CancelPercentPerDay { get; private set; }

    public void SetCancelSteps(IEnumerable<RentalCancelStep> steps, decimal limitPercent) =>
        SetCancelCharge(RentalCancelChargeType.ByTimeLeft, steps, null, limitPercent);

    /// <summary>
    /// Sets the charge one way only: steps (checked against the limit), or a percent per rental day
    /// that is above zero and at most the limit. The other way is cleared.
    /// </summary>
    public void SetCancelCharge(
        RentalCancelChargeType type, IEnumerable<RentalCancelStep> steps, decimal? percentPerDay, decimal limitPercent)
    {
        if (type == RentalCancelChargeType.PerRentalDay)
        {
            if (percentPerDay is not { } perDay || perDay <= 0)
            {
                throw new DomainException("Enter the charge for each rental day, e.g. 1%.");
            }

            if (perDay > limitPercent)
            {
                throw new DomainException($"This kind of item allows a cancellation charge of at most {limitPercent:0.##}%.");
            }

            CancelChargeType = type;
            CancelPercentPerDay = perDay;
            CancelSteps = [];
            return;
        }

        CancelSteps = RentalCancellation.Validated(steps, limitPercent);
        CancelChargeType = RentalCancelChargeType.ByTimeLeft;
        CancelPercentPerDay = null;
    }

    public void SetRate(RentalPriceType priceType, decimal price)
    {
        if (!Enum.IsDefined(priceType))
        {
            throw new DomainException("A rent item is charged per hour, per day, or per item.");
        }

        if (price <= 0)
        {
            throw new DomainException("The rate must be more than zero.");
        }

        PriceType = priceType;
        Price = price;
    }

    /// <summary>
    /// Asks an advance — ₹500 for the order, or ₹2 a chair — or none. An advance once set is
    /// mandatory for every order of the item.
    /// </summary>
    public void SetAdvance(RentalAdvanceType type, decimal? amount)
    {
        if (!Enum.IsDefined(type))
        {
            throw new DomainException("An advance is for the whole order, for each piece, or none.");
        }

        if (type == RentalAdvanceType.None)
        {
            AdvanceType = RentalAdvanceType.None;
            AdvanceAmount = null;
            return;
        }

        if (amount is not > 0)
        {
            throw new DomainException("Enter the advance amount, or choose no advance.");
        }

        AdvanceType = type;
        AdvanceAmount = amount;
    }

    public void SetQuantityOwned(int quantity)
    {
        if (quantity < 1)
        {
            throw new DomainException("You need at least one of this item to rent it out.");
        }

        QuantityOwned = quantity;
    }

    /// <summary>
    /// Sets the quantity, refusing a number below what is out with customers right now — 300
    /// chairs at a wedding cannot be owned by a business that says it has 200.
    /// </summary>
    public void SetQuantityOwned(int quantity, int quantityOut)
    {
        if (quantity < quantityOut)
        {
            throw new DomainException(
                $"{quantityOut} are out with customers now, so you have at least {quantityOut}.");
        }

        SetQuantityOwned(quantity);
    }
}

/// <summary>One photo (slots 0–2) or the one video of a rent item.</summary>
public class RentalItemMedia : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    public RentalMediaType MediaType { get; set; }

    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}

/// <summary>
/// Something the business needs to know before it rents the item out, in its own words — "Event
/// date and venue", "Floor type for the cutter".
/// </summary>
/// <remarks>Edited in place and soft-deleted when dropped, so answers given in step 2 keep their question.</remarks>
public class RentalItemQuestion : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    public string Prompt { get; set; } = string.Empty;

    /// <summary>Whether the customer must answer before booking.</summary>
    public bool IsRequired { get; set; }

    public short SortOrder { get; set; }
}

/// <summary>A district the item can be rented in.</summary>
public class RentalItemDistrict : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    public Guid DistrictId { get; set; }

    public RefDistrict District { get; set; } = null!;
}
