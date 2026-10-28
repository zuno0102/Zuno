using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// How one status, unit or kind reads in the apps: its words, its colour family and its icon.
/// </summary>
/// <remarks>
/// Grouped by where it is shown, not only by the enum behind it: the same application status reads
/// "Application sent" to the worker and "New" to the business, so each is its own group. Code
/// <c>*</c> is the group's fallback for a value the table does not list.
/// </remarks>
public class DisplayLabel : BaseEntity
{
    public string Group { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;

    public string Label { get; set; } = string.Empty;

    /// <summary>A shorter form where space is tight — "per day", "/ month".</summary>
    public string? ShortLabel { get; set; }

    /// <summary>A sentence that explains it, such as an empty list's message.</summary>
    public string? Detail { get; set; }

    /// <summary>The colour family: success, progress, waiting or danger.</summary>
    public string? Tone { get; set; }

    /// <summary>A Material icon name the app knows, such as <c>star_outline</c>.</summary>
    public string? IconName { get; set; }

    public int SortOrder { get; set; }
}
