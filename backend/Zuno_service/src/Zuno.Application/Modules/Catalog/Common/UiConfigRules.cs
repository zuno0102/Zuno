using System.Text.RegularExpressions;

namespace Zuno.Application.Modules.Catalog.Common;

/// <summary>What a usable label or colour row looks like. A row that fails keeps the built-in value.</summary>
public static partial class UiConfigRules
{
    /// <summary>The colour families the apps know how to paint.</summary>
    public static readonly IReadOnlySet<string> Tones =
        new HashSet<string>(StringComparer.Ordinal) { "success", "progress", "waiting", "danger" };

    public const string FallbackCode = "*";

    public static bool IsColor(string? value) => value is not null && ColorPattern().IsMatch(value);

    public static bool IsTone(string? tone) => tone is null || Tones.Contains(tone);

    /// <summary>Material icon names are lower snake case; anything else cannot be one the app knows.</summary>
    public static bool IsIconName(string? icon) => icon is null || IconPattern().IsMatch(icon);

    [GeneratedRegex("^#[0-9A-Fa-f]{8}$")]
    private static partial Regex ColorPattern();

    [GeneratedRegex("^[a-z0-9_]{1,60}$")]
    private static partial Regex IconPattern();
}
