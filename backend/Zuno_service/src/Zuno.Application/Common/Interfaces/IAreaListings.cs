using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Interfaces;

/// <summary>A business's live listing in the Rent or Marketplace API.</summary>
public record AreaListing(Guid Id, DateTimeOffset CreatedDate);

/// <summary>
/// A business's listings in the Rent and Marketplace APIs, read and paused through their internal
/// endpoints with the shared key. Service's own listings are read from its own database instead.
/// </summary>
/// <remarks>Throws <see cref="AreaUnavailableException"/> when an area cannot be reached or is not set up.</remarks>
public interface IAreaListings
{
    Task<IReadOnlyList<AreaListing>> LiveAsync(ListingArea area, Guid ownerUserId, CancellationToken cancellationToken);

    Task PauseAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken);

    Task ResumeAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken);
}

/// <summary>The Rent or Marketplace API could not be asked just now.</summary>
public class AreaUnavailableException(ListingArea area, Exception? inner = null)
    : Exception($"The {area} API could not be reached.", inner)
{
    public ListingArea Area { get; } = area;
}
