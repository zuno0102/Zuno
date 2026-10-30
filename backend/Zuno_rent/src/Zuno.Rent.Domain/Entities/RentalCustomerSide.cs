using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// The business behind rent items, as customers see it: its name, logo and whether it is verified.
/// Read from the Service API with the business's own login and kept here, so browsing rent items
/// needs no call to Service — and only verified businesses' items are shown.
/// </summary>
public class RentalBusiness
{
    /// <summary>The business's login id — the same as <see cref="RentalItem.OwnerUserId"/>.</summary>
    public Guid OwnerUserId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? LogoUrl { get; set; }

    public bool IsVerified { get; set; }

    public DateTimeOffset RefreshedAt { get; set; }

    /// <summary>
    /// Where customers pay the business by UPI, e.g. <c>joyrentals@okhdfcbank</c> — the QR on an order
    /// is made from it. Set by the business in Rent; a profile refresh never touches it.
    /// </summary>
    public string? UpiId { get; set; }
}

/// <summary>A customer's answer to one of the item's questions, with the question's wording copied as asked.</summary>
public class RentalOrderAnswer : BaseEntity
{
    public Guid RentalOrderId { get; set; }

    /// <summary>The question answered; kept even if the business later removes it.</summary>
    public Guid? QuestionId { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public string Answer { get; set; } = string.Empty;
}

/// <summary>
/// One section of the customer's Rent home — "Popular near you" as a strip, "Explore" as a grid.
/// Table-driven: names, order, how many and the layout change without a release.
/// </summary>
public class RentalHomeSection
{
    /// <summary>Stable key, e.g. <c>popular</c>.</summary>
    public string Code { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public RentalHomeLayout Layout { get; set; }

    /// <summary>How many items the section shows.</summary>
    public short Size { get; set; }

    /// <summary>Most-rented first (then shuffled) rather than plain shuffled.</summary>
    public bool ByPopularity { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
