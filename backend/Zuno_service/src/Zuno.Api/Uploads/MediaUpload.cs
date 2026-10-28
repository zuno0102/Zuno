using Zuno.Application.Common;

namespace Zuno.Api.Uploads;

/// <summary>
/// The one check every public image and video upload goes through: what the file really is, judged by
/// its first bytes, and the extension it is stored under, taken from that.
/// </summary>
/// <remarks>
/// Never from the client's file name or its declared content type — both are the caller's to choose.
/// Five upload endpoints used to keep the name's extension, so a business could upload "x.html" or
/// "x.svg" with an image content type and have it served from the API's own origin as a web page.
/// Public uploads are served by extension, so the extension must be one the server chose.
/// </remarks>
public static class MediaUpload
{
    public const string ImageRule = "Image must be a JPEG, PNG or WebP file.";

    public const string VideoRule = "Video must be an MP4, MOV or WebM file.";

    /// <summary>".jpg", ".png" or ".webp" for a real image, or null for anything else.</summary>
    public static async Task<string?> ImageExtensionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        // Both must agree: what the client says it sent, and what the bytes are.
        if (!file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var detected = FileSignature.Detect(await HeaderAsync(file, cancellationToken));
        return detected is { ContentType: "image/jpeg" or "image/png" or "image/webp" }
            ? "." + detected.Extension
            : null;
    }

    /// <summary>".mp4", ".mov" or ".webm" for a real video, or null for anything else.</summary>
    public static async Task<string?> VideoExtensionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        if (!file.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var detected = FileSignature.DetectVideo(await HeaderAsync(file, cancellationToken));
        return detected is null ? null : "." + detected.Extension;
    }

    private static async Task<byte[]> HeaderAsync(IFormFile file, CancellationToken cancellationToken)
    {
        // A form file can be opened more than once; the caller opens it again to save it.
        await using var stream = file.OpenReadStream();
        var header = new byte[FileSignature.HeaderLength];
        var read = 0;
        while (read < header.Length)
        {
            var n = await stream.ReadAsync(header.AsMemory(read), cancellationToken);
            if (n == 0)
            {
                break;
            }

            read += n;
        }

        return header[..read];
    }
}
