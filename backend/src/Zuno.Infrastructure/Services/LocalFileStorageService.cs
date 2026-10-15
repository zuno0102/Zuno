using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Writes uploaded files to a local directory under the content root. Swapping in cloud blob
/// storage later is a one-file change behind IFileStorageService — no caller needs to change.
/// </summary>
public class LocalFileStorageService(
    IHostEnvironment hostEnvironment,
    IOptions<FileStorageSettings> settings,
    IDateTimeProvider dateTimeProvider)
    : IFileStorageService
{
    public Task<string> SaveServiceImageAsync(
        Guid serviceId, int slotIndex, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveAsync(serviceId, $"image-{slotIndex}", fileExtension, content, cancellationToken);

    public Task<string> SaveServiceVideoAsync(
        Guid serviceId, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveAsync(serviceId, "video", fileExtension, content, cancellationToken);

    public Task<string> SaveServiceVariantImageAsync(
        Guid serviceId, Guid variantId, int slotIndex, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveVariantAsync(serviceId, variantId, $"image-{slotIndex}", fileExtension, content, cancellationToken);

    public Task<string> SaveServiceVariantVideoAsync(
        Guid serviceId, Guid variantId, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        SaveVariantAsync(serviceId, variantId, "video", fileExtension, content, cancellationToken);

    public async Task<string> SaveHiringPostImageAsync(
        Guid hiringPostId, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "hiring-posts", hiringPostId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, "image.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"image{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/hiring-posts/{hiringPostId}/{fileName}";
    }

    public async Task<string> SaveBusinessLogoAsync(
        Guid businessOwnerProfileId, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "businesses", businessOwnerProfileId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        // Clearing every extension, not just the incoming one: swapping a PNG for a JPEG would
        // otherwise leave the old file behind, and a later profile read has no way to tell which
        // of the two is current.
        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, "logo.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"logo{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/businesses/{businessOwnerProfileId}/{fileName}";
    }

    public async Task<string> SaveWorkerPhotoAsync(
        Guid workerProfileId, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "workers", workerProfileId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        // Every extension cleared, not just the incoming one: replacing a PNG with a JPEG would
        // otherwise leave both behind with no way to tell which is current.
        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, "photo.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"photo{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/workers/{workerProfileId}/{fileName}";
    }

    public async Task<string> SaveAccountPhotoAsync(
        Guid userId, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "users", userId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        // Every earlier photo, whatever its name or extension. The glob is "photo*" rather than
        // "photo.*" because the name now carries a version, and the older unversioned "photo.jpg"
        // from before that change still has to be swept up.
        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, "photo*.*"))
        {
            File.Delete(existingFile);
        }

        // Versioned by the moment it was saved, so a new picture is a new address.
        //
        // Writing every upload to the same "photo.jpg" meant the URL never changed, and nothing
        // between the file and the screen could tell that the bytes behind it had: the phone's image
        // cache, the decoded frame already held by the avatar widget, and any proxy in between all
        // went on serving the previous photo. The customer saw "Photo updated." and the old picture,
        // until they left the tab and came back and the widget resolved the URL afresh.
        var version = dateTimeProvider.UtcNow.ToUnixTimeMilliseconds();
        var fileName = $"photo-{version}{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/users/{userId}/{fileName}";
    }

    public async Task<string> SaveCategoryIconAsync(
        Guid categoryId, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "categories", categoryId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        // Every extension cleared, not just the incoming one: replacing a PNG with a WebP would
        // otherwise leave both behind with no way to tell which is current.
        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, "icon.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"icon{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/categories/{categoryId}/{fileName}";
    }

    public void DeleteFile(string publicUrl)
    {
        if (!publicUrl.StartsWith(settings.Value.PublicPath, StringComparison.Ordinal))
        {
            return;
        }

        var relativePath = settings.Value.RootPath + publicUrl[settings.Value.PublicPath.Length..];
        var absolutePath = Path.Combine(hostEnvironment.ContentRootPath, relativePath.Replace('/', Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar));

        if (File.Exists(absolutePath))
        {
            File.Delete(absolutePath);
        }
    }

    private async Task<string> SaveAsync(
        Guid serviceId, string baseFileName, string fileExtension, Stream content, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "services", serviceId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, $"{baseFileName}.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"{baseFileName}{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/services/{serviceId}/{fileName}";
    }

    private async Task<string> SaveVariantAsync(
        Guid serviceId, Guid variantId, string baseFileName, string fileExtension, Stream content, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine(settings.Value.RootPath, "services", serviceId.ToString(), "variants", variantId.ToString());
        var absoluteDirectory = Path.Combine(hostEnvironment.ContentRootPath, relativeDirectory);

        Directory.CreateDirectory(absoluteDirectory);

        foreach (var existingFile in Directory.EnumerateFiles(absoluteDirectory, $"{baseFileName}.*"))
        {
            File.Delete(existingFile);
        }

        var fileName = $"{baseFileName}{fileExtension}";
        var absolutePath = Path.Combine(absoluteDirectory, fileName);
        await using (var fileStream = File.Create(absolutePath))
        {
            await content.CopyToAsync(fileStream, cancellationToken);
        }

        return $"{settings.Value.PublicPath}/services/{serviceId}/variants/{variantId}/{fileName}";
    }
}
