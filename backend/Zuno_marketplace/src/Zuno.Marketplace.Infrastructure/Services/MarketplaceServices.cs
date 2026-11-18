using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;

namespace Zuno.Marketplace.Infrastructure.Services;

/// <summary>The caller, from the shared login's token — the same claim the Service module reads.</summary>
public class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    public Guid? UserId =>
        Guid.TryParse(httpContextAccessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
            ? id
            : null;
}

/// <summary>Where uploads go and how big they may be (section <c>FileStorage</c>).</summary>
public class MarketplaceFileStorageSettings
{
    public const string SectionName = "FileStorage";

    public string RootPath { get; set; } = "wwwroot/uploads";

    public string PublicPath { get; set; } = "/uploads";

    public long MaxFileSizeBytes { get; set; } = 5 * 1024 * 1024;
}

/// <summary>
/// Keeps post photos under <c>{RootPath}/marketplace/{postId}/</c>.
/// </summary>
/// <remarks>
/// Every save gets a fresh random name, so a replaced photo is a new URL and the app's image cache can
/// never keep showing the old one. The earlier file in that slot is cleared first.
/// </remarks>
public partial class MarketplaceMediaStorage(IHostEnvironment hostEnvironment, IOptions<MarketplaceFileStorageSettings> settings)
    : IMarketplaceMediaStorage
{
    private const string Folder = "marketplace";

    public Task<string> SaveImageAsync(
        Guid postId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken, Guid? variantId = null)
    {
        // A colour / size's photos are named apart, so its slot 0 never replaces the cover.
        var slotName = variantId is { } variant ? $"variant-{variant:N}-{slot}" : $"image-{slot}";
        return SaveAsync(postId, slotName, content, fileExtension, cancellationToken);
    }

    // In a folder of the order's own id, beside the posts' folders: ids never collide.
    public Task<string> SaveOrderReceiptAsync(Guid orderId, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveAsync(orderId, "receipt-0", content, fileExtension, cancellationToken);

    private async Task<string> SaveAsync(Guid ownerId, string slotName, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var extension = fileExtension.ToLowerInvariant();
        if (!SafeExtension().IsMatch(extension))
        {
            throw new ArgumentException("Unsupported file extension.", nameof(fileExtension));
        }

        var directory = PostDirectory(ownerId);
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

        return $"{settings.Value.PublicPath}/{Folder}/{ownerId}/{fileName}";
    }

    public void Delete(string publicUrl)
    {
        var prefix = $"{settings.Value.PublicPath}/{Folder}/";
        if (string.IsNullOrEmpty(publicUrl) || !publicUrl.StartsWith(prefix, StringComparison.Ordinal))
        {
            return;
        }

        // Only "{guid}/{our file name}" is accepted after the prefix, so a crafted URL cannot reach
        // outside the post's folder.
        var parts = publicUrl[prefix.Length..].Split('/');
        if (parts.Length != 2 || !Guid.TryParse(parts[0], out var postId) || !SafeFileName().IsMatch(parts[1]))
        {
            return;
        }

        var path = Path.Combine(PostDirectory(postId), parts[1]);
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    private string PostDirectory(Guid postId) =>
        Path.Combine(hostEnvironment.ContentRootPath, settings.Value.RootPath, Folder, postId.ToString());

    [GeneratedRegex(@"^\.[a-z0-9]{1,5}$")]
    private static partial Regex SafeExtension();

    // The post's own photos ("image-0-…"), a colour / size's ("variant-{32 hex}-0-…") and an order's
    // courier receipt ("receipt-0-…"); nothing else.
    [GeneratedRegex(@"^(image|receipt|variant-[a-f0-9]{32})-\d+-[a-f0-9]{12}\.[a-z0-9]{1,5}$")]
    private static partial Regex SafeFileName();
}
