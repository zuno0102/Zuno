using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Writes private documents to a directory outside the web root, so the static file middleware can
/// never serve them. Swapping in private blob storage later is a change to this class only.
/// </summary>
public class LocalPrivateDocumentStore(
    IHostEnvironment hostEnvironment,
    IOptions<FileStorageSettings> settings) : IPrivateDocumentStore
{
    public async Task<string> SaveAsync(
        string folder, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        // Random, server-chosen names: nothing the applicant typed ever reaches the file system.
        var key = $"{folder.Trim('/')}/{Guid.NewGuid():N}.{fileExtension.TrimStart('.')}";
        var absolutePath = Resolve(key);

        Directory.CreateDirectory(Path.GetDirectoryName(absolutePath)!);

        await using var fileStream = File.Create(absolutePath);
        await content.CopyToAsync(fileStream, cancellationToken);

        return key;
    }

    public Stream? OpenRead(string key)
    {
        var absolutePath = Resolve(key);
        return File.Exists(absolutePath) ? File.OpenRead(absolutePath) : null;
    }

    public void DeleteFolder(string folder)
    {
        var absolutePath = Resolve(folder);

        if (Directory.Exists(absolutePath))
        {
            Directory.Delete(absolutePath, recursive: true);
        }
    }

    /// <summary>
    /// The absolute path behind a key, refusing any key that would land outside the private root.
    /// </summary>
    /// <remarks>
    /// Keys are built by the server, but a row edited by hand or a future bug must still not be able to
    /// read or delete "../../appsettings.json".
    /// </remarks>
    private string Resolve(string key)
    {
        var root = Path.GetFullPath(Path.Combine(hostEnvironment.ContentRootPath, settings.Value.PrivateRootPath));
        var absolutePath = Path.GetFullPath(Path.Combine(root, key.Replace('/', Path.DirectorySeparatorChar)));

        if (!absolutePath.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("A document key resolved outside private storage.");
        }

        return absolutePath;
    }
}
