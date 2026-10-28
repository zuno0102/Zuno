using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>Limits for full-time vacancies. Prices and listing days live in the fee plan table, not here.</summary>
public class VacancySettings
{
    public const string SectionName = "Vacancies";

    [Range(1, 100)]
    public int DefaultPageSize { get; set; } = 20;

    [Range(1, 100)]
    public int MaxPageSize { get; set; } = 50;

    /// <summary>How many custom fields one vacancy may have.</summary>
    [Range(1, 50)]
    public int MaxRequirements { get; set; } = 15;

    /// <summary>File types a File field accepts, without the dot. Checked against the file's real content.</summary>
    /// <remarks>
    /// Empty by default and required from configuration: the binder appends configured items to a
    /// default array rather than replacing it, so a default here could never be narrowed.
    /// </remarks>
    [MinLength(1)]
    public string[] AllowedFileExtensions { get; set; } = [];

    /// <summary>The largest one uploaded file may be.</summary>
    [Range(1, 50 * 1024 * 1024)]
    public long MaxFileSizeBytes { get; set; } = 5 * 1024 * 1024;

    /// <summary>The most one application's files may add up to.</summary>
    [Range(1, 200 * 1024 * 1024)]
    public long MaxApplicationUploadBytes { get; set; } = 30 * 1024 * 1024;

    /// <summary>Clamps a requested page size to the configured bounds.</summary>
    public int PageSize(int? requested) =>
        requested is > 0 ? Math.Min(requested.Value, MaxPageSize) : DefaultPageSize;

    /// <summary>Whether a file with this extension (no dot, any case) may be uploaded.</summary>
    public bool AcceptsFile(string extension) =>
        AllowedFileExtensions.Contains(extension.TrimStart('.'), StringComparer.OrdinalIgnoreCase);
}
