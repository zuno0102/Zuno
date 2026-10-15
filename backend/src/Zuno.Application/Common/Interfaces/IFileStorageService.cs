namespace Zuno.Application.Common.Interfaces;

public interface IFileStorageService
{
    /// <summary>
    /// Saves an uploaded service image into a fixed slot (0-2) and returns the root-relative
    /// URL clients should resolve against their own API base URL. Re-uploading to the same slot
    /// replaces whatever was there before (any prior file for that slot is deleted first).
    /// </summary>
    Task<string> SaveServiceImageAsync(
        Guid serviceId, int slotIndex, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Saves an uploaded service video (a service has at most one) and returns the root-relative
    /// URL. Re-uploading replaces the previous video, if any.
    /// </summary>
    Task<string> SaveServiceVideoAsync(
        Guid serviceId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Saves an uploaded service-variant image into a fixed slot (0-2), mirroring the parent
    /// service's slots, and returns the root-relative URL. Re-uploading to the same slot
    /// replaces whatever was there before.
    /// </summary>
    Task<string> SaveServiceVariantImageAsync(
        Guid serviceId, Guid variantId, int slotIndex, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Saves an uploaded service-variant video (a variant has at most one) and returns the
    /// root-relative URL. Re-uploading replaces the previous video, if any.
    /// </summary>
    Task<string> SaveServiceVariantVideoAsync(
        Guid serviceId, Guid variantId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Saves an uploaded hiring-post image (a post has at most one) and returns the
    /// root-relative URL. Re-uploading replaces the previous image, if any.
    /// </summary>
    Task<string> SaveHiringPostImageAsync(
        Guid hiringPostId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Saves a business's profile picture (a business has at most one) and returns the
    /// root-relative URL. Re-uploading replaces the previous picture, if any.
    /// </summary>
    Task<string> SaveBusinessLogoAsync(
        Guid businessOwnerProfileId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Stores a worker's own picture, replacing any previous one, and returns its root-relative URL.
    /// </summary>
    Task<string> SaveWorkerPhotoAsync(
        Guid workerProfileId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Stores a person's own profile picture, replacing any previous one, and returns its URL.
    /// </summary>
    /// <remarks>
    /// Keyed on the user rather than a role profile: the picture belongs to the person, and an account
    /// that is both a customer and a worker is still one face.
    /// </remarks>
    Task<string> SaveAccountPhotoAsync(
        Guid userId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Stores a category's icon, replacing any previous one, and returns its root-relative URL.
    /// </summary>
    /// <remarks>
    /// Lets the app owner give a new category its own artwork without an app release. The client can
    /// only draw icons compiled into it, so without this a category wanting anything outside that
    /// set waits for a release.
    /// </remarks>
    Task<string> SaveCategoryIconAsync(
        Guid categoryId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>
    /// Deletes the file behind a previously-returned public URL, if it still exists.
    /// </summary>
    void DeleteFile(string publicUrl);
}
