namespace Zuno.Application.Common;

/// <summary>
/// Identifies an uploaded file by its first bytes rather than by the name or content type the client
/// claimed — both of which an attacker chooses.
/// </summary>
public static class FileSignature
{
    /// <summary>How many leading bytes <see cref="Detect"/> needs to see.</summary>
    public const int HeaderLength = 12;

    /// <summary>The file's real type, or null when it is none of the kinds the app accepts.</summary>
    public static DetectedFile? Detect(ReadOnlySpan<byte> header)
    {
        if (header.StartsWith("%PDF-"u8))
        {
            return new DetectedFile("pdf", "application/pdf");
        }

        if (header.StartsWith((ReadOnlySpan<byte>)[0xFF, 0xD8, 0xFF]))
        {
            return new DetectedFile("jpg", "image/jpeg");
        }

        if (header.StartsWith((ReadOnlySpan<byte>)[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        {
            return new DetectedFile("png", "image/png");
        }

        if (header.Length >= HeaderLength && header[..4].SequenceEqual("RIFF"u8) && header[8..12].SequenceEqual("WEBP"u8))
        {
            return new DetectedFile("webp", "image/webp");
        }

        return null;
    }

    /// <summary>The video's real type — MP4, MOV or WebM — or null when it is none of them.</summary>
    /// <remarks>
    /// MP4 and MOV are both ISO media files: an "ftyp" box at byte 4, then a brand; QuickTime's is
    /// "qt  ". WebM is Matroska, which opens with the EBML magic number.
    /// </remarks>
    public static DetectedFile? DetectVideo(ReadOnlySpan<byte> header)
    {
        if (header.Length >= HeaderLength && header[4..8].SequenceEqual("ftyp"u8))
        {
            return header[8..12].SequenceEqual("qt  "u8)
                ? new DetectedFile("mov", "video/quicktime")
                : new DetectedFile("mp4", "video/mp4");
        }

        if (header.StartsWith((ReadOnlySpan<byte>)[0x1A, 0x45, 0xDF, 0xA3]))
        {
            return new DetectedFile("webm", "video/webm");
        }

        return null;
    }
}

/// <param name="Extension">)Without the dot, and canonical — "jpg", never "jpeg".</param>
public sealed record DetectedFile(string Extension, string ContentType)
{
    /// <summary>The extensions a document type may list for this kind of file.</summary>
    public IEnumerable<string> Aliases => Extension == "jpg" ? ["jpg", "jpeg"] : [Extension];
}
