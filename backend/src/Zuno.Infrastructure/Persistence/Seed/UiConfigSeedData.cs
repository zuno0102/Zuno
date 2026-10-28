using System.Text.Json;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// The built-in labels and colours, read from the JSON files embedded beside this class.
/// </summary>
/// <remarks>
/// One source for three things: the seed rows of <c>display_labels</c> and <c>theme_colors</c>, the
/// fallback the store uses for a row that is missing or unusable, and — through a byte-for-byte copy
/// the app bundles — what the app shows before it has ever reached the server.
/// </remarks>
public static class UiConfigSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 10, 28, 0, 0, 0, TimeSpan.Zero);

    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    /// <summary>Every embedded file, by name: <c>colors.json</c>, <c>labels.vacancy.json</c> …</summary>
    public static IReadOnlyDictionary<string, string> Files { get; } = ReadFiles();

    public static IReadOnlyDictionary<string, IReadOnlyDictionary<string, UiLabelDto>> Labels { get; } = ReadLabels();

    public static IReadOnlyDictionary<string, UiColorDto> Colors { get; } = ReadColors();

    public static DisplayLabel[] LabelRows { get; } =
    [
        .. Labels.SelectMany(group => group.Value.Select(entry => new DisplayLabel
        {
            Id = DeterministicGuid.From($"display-label:{group.Key}:{entry.Key}"),
            Group = group.Key,
            Code = entry.Key,
            Label = entry.Value.Label,
            ShortLabel = entry.Value.Short,
            Detail = entry.Value.Detail,
            Tone = entry.Value.Tone,
            IconName = entry.Value.Icon,
            SortOrder = entry.Value.Sort,
            CreatedDate = SeedDate,
        })),
    ];

    public static ThemeColor[] ColorRows { get; } =
    [
        .. Colors.Select(c => new ThemeColor
        {
            Id = DeterministicGuid.From($"theme-color:{c.Key}"),
            Key = c.Key,
            LightValue = c.Value.Light,
            DarkValue = c.Value.Dark,
            CreatedDate = SeedDate,
        }),
    ];

    private static Dictionary<string, string> ReadFiles()
    {
        var assembly = typeof(UiConfigSeedData).Assembly;
        const string prefix = "UiConfig.";

        return assembly.GetManifestResourceNames()
            .Where(n => n.StartsWith(prefix, StringComparison.Ordinal))
            .Order(StringComparer.Ordinal)
            .ToDictionary(
                n => n[prefix.Length..],
                n =>
                {
                    using var stream = assembly.GetManifestResourceStream(n)!;
                    using var reader = new StreamReader(stream);
                    return reader.ReadToEnd();
                });
    }

    private static Dictionary<string, IReadOnlyDictionary<string, UiLabelDto>> ReadLabels()
    {
        var labels = new Dictionary<string, IReadOnlyDictionary<string, UiLabelDto>>(StringComparer.Ordinal);

        foreach (var (name, text) in Files.Where(f => f.Key.StartsWith("labels.", StringComparison.Ordinal)))
        {
            var file = JsonSerializer.Deserialize<LabelFile>(text, Json)
                ?? throw new InvalidOperationException($"{name} is empty.");

            foreach (var (group, entries) in file.Groups)
            {
                // A group split across two files would silently lose one half; refuse it at start-up.
                if (!labels.TryAdd(group, entries))
                {
                    throw new InvalidOperationException($"Label group {group} is defined in more than one file.");
                }
            }
        }

        return labels;
    }

    private static Dictionary<string, UiColorDto> ReadColors()
    {
        var file = JsonSerializer.Deserialize<ColorFile>(Files["colors.json"], Json)
            ?? throw new InvalidOperationException("colors.json is empty.");

        return new Dictionary<string, UiColorDto>(file.Colors, StringComparer.Ordinal);
    }

    private sealed record LabelFile(Dictionary<string, Dictionary<string, UiLabelDto>> Groups);

    private sealed record ColorFile(Dictionary<string, UiColorDto> Colors);
}
