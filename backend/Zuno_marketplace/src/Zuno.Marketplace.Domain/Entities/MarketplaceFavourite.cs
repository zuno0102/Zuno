namespace Zuno.Marketplace.Domain.Entities;

/// <summary>
/// A post a customer saved to their wishlist. A personal choice, not a business record: removing it
/// deletes the row, and saving it again adds a new one.
/// </summary>
public class MarketplaceFavourite
{
    public Guid UserId { get; set; }

    public Guid PostId { get; set; }

    public MarketplacePost Post { get; set; } = null!;

    public DateTimeOffset CreatedDate { get; set; }
}
