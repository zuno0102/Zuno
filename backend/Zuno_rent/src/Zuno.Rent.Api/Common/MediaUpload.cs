namespace Zuno.Rent.Api.Common;

/// <summary>
/// Every photo and video upload is judged by its first bytes, and stored under the extension the
/// server chose from them — never the client's file name or content type, which an attacker picks.
/// </summary>
/// <remarks>The same rules as the Service API's upload check.</remarks>
public static class MediaUpload
{
    public const string ImageRule = "Image must be a JPEG, PNG or WebP file.";

    public const string VideoRule = "Video must be an MP4, MOV or WebM file.";

    private const int HeaderLength = 12;

    /// <summary>".jpg", ".png" or ".webp" for a real image, or null for anything else.</summary>
    public static async Task<string?> ImageExtensionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        if (!file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return ImageExtension(await HeaderAsync(file, cancellationToken));
    }

    /// <summary>".mp4", ".mov" or ".webm" for a real video, or null for anything else.</summary>
    public static async Task<string?> VideoExtensionAsync(IFormFile file, CancellationToken cancellationToken)
    {
        if (!file.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return VideoExtension(await HeaderAsync(file, cancellationToken));
    }

    internal static string? ImageExtension(ReadOnlySpan<byte> header)
    {
        if (header.StartsWith((ReadOnlySpan<byte>)[0xFF, 0xD8, 0xFF]))
        {
            return ".jpg";
        }

        if (header.StartsWith((ReadOnlySpan<byte>)[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        {
            return ".png";
        }

        if (header.Length >= HeaderLength && header[..4].SequenceEqual("RIFF"u8) && header[8..12].SequenceEqual("WEBP"u8))
        {
            return ".webp";
        }

        return null;
    }

    /// <remarks>
    /// MP4 and MOV both have an "ftyp" box at byte 4, then a brand; QuickTime's is "qt  ". WebM opens
    /// with the EBML magic number.
    /// </remarks>
    internal static string? VideoExtension(ReadOnlySpan<byte> header)
    {
        if (header.Length >= HeaderLength && header[4..8].SequenceEqual("ftyp"u8))
        {
            return header[8..12].SequenceEqual("qt  "u8) ? ".mov" : ".mp4";
        }

        if (header.StartsWith((ReadOnlySpan<byte>)[0x1A, 0x45, 0xDF, 0xA3]))
        {
            return ".webm";
        }

        return null;
    }

    private static async Task<byte[]> HeaderAsync(IFormFile file, CancellationToken cancellationToken)
    {
        // A form file can be opened more than once; the caller opens it again to save it.
        await using var stream = file.OpenReadStream();
        var header = new byte[HeaderLength];
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
