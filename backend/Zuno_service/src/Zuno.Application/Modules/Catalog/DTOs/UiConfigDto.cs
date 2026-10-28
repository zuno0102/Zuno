namespace Zuno.Application.Modules.Catalog.DTOs;

/// <summary>Every label and colour the apps show, from the display_labels and theme_colors tables.</summary>
public sealed class UiConfigDto
{
    /// <summary>Changes whenever any label or colour does, so an app can skip a download it already has.</summary>
    public string Version { get; init; } = string.Empty;

    /// <summary>Group → code → how it reads.</summary>
    public IReadOnlyDictionary<string, IReadOnlyDictionary<string, UiLabelDto>> Labels { get; init; } =
        new Dictionary<string, IReadOnlyDictionary<string, UiLabelDto>>();

    public IReadOnlyDictionary<string, UiColorDto> Colors { get; init; } = new Dictionary<string, UiColorDto>();
}

public sealed record UiLabelDto
{
    public string Label { get; init; } = string.Empty;

    public string? Short { get; init; }

    public string? Detail { get; init; }

    public string? Tone { get; init; }

    public string? Icon { get; init; }

    public int Sort { get; init; }
}

public sealed record UiColorDto(string Light, string Dark);
