namespace Zuno.Application.Rental.Common;

/// <summary>
/// Where a rent item's photos and video are kept. The Rent module's own storage, so it never
/// changes how the rest of the app saves files.
/// </summary>
public interface IRentalMediaStorage
{
    /// <summary>Saves a photo into <paramref name="slot"/>, replacing whatever was there. Returns its public URL.</summary>
    Task<string> SaveImageAsync(
        Guid rentalItemId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Saves the item's video, replacing any earlier one. Returns its public URL.</summary>
    Task<string> SaveVideoAsync(
        Guid rentalItemId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Deletes the file behind a URL this storage returned, if it is still there.</summary>
    void Delete(string publicUrl);
}
