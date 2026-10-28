namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Storage for personal documents — Aadhaar, resumes — that must never be reachable by URL.
/// </summary>
/// <remarks>
/// Kept apart from <see cref="IFileStorageService"/>, whose files are public by design: anything there
/// is served to whoever has the link. A document saved here is only ever read back through an endpoint
/// that has checked who is asking.
/// </remarks>
public interface IPrivateDocumentStore
{
    /// <summary>Saves a document under <paramref name="folder"/> with a random name and returns its key.</summary>
    Task<string> SaveAsync(string folder, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Opens a saved document for reading, or returns null if it no longer exists.</summary>
    Stream? OpenRead(string key);

    /// <summary>Deletes a folder and everything in it. Doing nothing when it is already gone.</summary>
    void DeleteFolder(string folder);
}
