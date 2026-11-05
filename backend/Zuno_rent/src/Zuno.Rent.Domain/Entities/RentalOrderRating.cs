using Zuno.Rent.Domain.Common;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// The customer's stars for one rental that went well — returned and fully paid. One per order,
/// never changed: the item and the business are rated from these rows.
/// </summary>
/// <remarks>
/// The item and the business are copied onto the rating, so an item's stars and a business's
/// totals are read without a join to the orders.
/// </remarks>
public class RentalOrderRating : BaseEntity
{
    /// <summary>The main order rated — never an add-on, which is part of its parent.</summary>
    public Guid RentalOrderId { get; set; }

    public Guid RentalItemId { get; set; }

    /// <summary>The business rated.</summary>
    public Guid OwnerUserId { get; set; }

    /// <summary>The customer who rated it.</summary>
    public Guid CustomerUserId { get; set; }

    /// <summary>From <see cref="RentalRatingFields.MinScore"/> to <see cref="RentalRatingFields.MaxScore"/> stars.</summary>
    public short Score { get; set; }

    public string? Comment { get; set; }
}

/// <summary>The shape of a rating, checked the same way in the validator and the database.</summary>
public static class RentalRatingFields
{
    public const short MinScore = 1;

    public const short MaxScore = 5;

    public const int CommentMaxLength = 1000;
}
