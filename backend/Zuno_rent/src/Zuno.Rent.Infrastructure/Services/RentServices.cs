using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Infrastructure.Services;

/// <summary>The caller, from the shared login's token — the same claim the Service module reads.</summary>
public class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    public Guid? UserId =>
        Guid.TryParse(httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
            ? id
            : null;
}

/// <summary>Where uploads go and how big they may be (section <c>FileStorage</c>).</summary>
public class RentFileStorageSettings
{
    public const string SectionName = "FileStorage";

    public string RootPath { get; set; } = "wwwroot/uploads";

    public string PublicPath { get; set; } = "/uploads";

    public long MaxFileSizeBytes { get; set; } = 5 * 1024 * 1024;

    public long MaxVideoFileSizeBytes { get; set; } = 25 * 1024 * 1024;
}

/// <summary>
/// Keeps rent item photos and videos under <c>{RootPath}/rentals/{itemId}/</c>.
/// </summary>
/// <remarks>
/// Every save gets a fresh random name, so a replaced photo is a new URL and the app's image cache can
/// never keep showing the old one. The earlier file in that slot is cleared first.
/// </remarks>
public partial class RentMediaStorage(IHostEnvironment hostEnvironment, IOptions<RentFileStorageSettings> settings)
    : IRentMediaStorage
{
    private const string Folder = "rentals";

    public Task<string> SaveImageAsync(
        Guid rentalItemId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveAsync(rentalItemId, $"image-{slot}", content, fileExtension, cancellationToken);

    public Task<string> SaveVideoAsync(
        Guid rentalItemId, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveAsync(rentalItemId, "video", content, fileExtension, cancellationToken);

    public void Delete(string publicUrl)
    {
        var prefix = $"{settings.Value.PublicPath}/{Folder}/";
        if (string.IsNullOrEmpty(publicUrl) || !publicUrl.StartsWith(prefix, StringComparison.Ordinal))
        {
            return;
        }

        // Only "{guid}/{our file name}" is accepted after the prefix, so a crafted URL cannot reach
        // outside the item's folder.
        var parts = publicUrl[prefix.Length..].Split('/');
        if (parts.Length != 2 || !Guid.TryParse(parts[0], out var itemId) || !SafeFileName().IsMatch(parts[1]))
        {
            return;
        }

        var path = Path.Combine(ItemDirectory(itemId), parts[1]);
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    private async Task<string> SaveAsync(
        Guid rentalItemId, string slotName, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var extension = fileExtension.ToLowerInvariant();
        if (!SafeExtension().IsMatch(extension))
        {
            throw new ArgumentException("Unsupported file extension.", nameof(fileExtension));
        }

        var directory = ItemDirectory(rentalItemId);
        Directory.CreateDirectory(directory);

        foreach (var earlier in Directory.EnumerateFiles(directory, $"{slotName}-*"))
        {
            File.Delete(earlier);
        }

        var fileName = $"{slotName}-{Convert.ToHexString(RandomNumberGenerator.GetBytes(6)).ToLowerInvariant()}{extension}";
        await using (var file = File.Create(Path.Combine(directory, fileName)))
        {
            await content.CopyToAsync(file, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/{Folder}/{rentalItemId}/{fileName}";
    }

    private string ItemDirectory(Guid rentalItemId) =>
        Path.Combine(hostEnvironment.ContentRootPath, settings.Value.RootPath, Folder, rentalItemId.ToString());

    [GeneratedRegex(@"^\.[a-z0-9]{1,5}$")]
    private static partial Regex SafeExtension();

    [GeneratedRegex(@"^(image-\d+|video)-[a-f0-9]{12}\.[a-z0-9]{1,5}$")]
    private static partial Regex SafeFileName();
}
