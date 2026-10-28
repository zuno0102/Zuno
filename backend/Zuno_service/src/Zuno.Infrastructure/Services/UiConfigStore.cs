using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.Common;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Holds the rows of <c>display_labels</c> and <c>theme_colors</c> in memory, laid over the built-in
/// values, one copy per instance.
/// </summary>
/// <remarks>
/// Same shape as the platform settings store: swapped in whole, read without a lock or a query. A row
/// that is unusable — an unknown tone, a colour that is not <c>#AARRGGBB</c>, a blank label — is
/// skipped and logged, so the built-in value stays in force for that one entry.
/// </remarks>
public sealed class UiConfigStore(
    IServiceScopeFactory scopeFactory,
    ILogger<UiConfigStore> logger) : IUiConfigStore
{
    private static readonly JsonSerializerOptions VersionJson = new(JsonSerializerDefaults.Web);

    private UiConfigDto _current = Build(UiConfigSeedData.Labels, UiConfigSeedData.Colors);

    public UiConfigDto Current => Volatile.Read(ref _current);

    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ZunoDbContext>();

        var labelRows = await dbContext.DisplayLabels.AsNoTracking().ToListAsync(cancellationToken);
        var colorRows = await dbContext.ThemeColors.AsNoTracking().ToListAsync(cancellationToken);

        Volatile.Write(ref _current, Merge(labelRows, colorRows, (what, why) =>
            logger.LogWarning("UI config {What} is unusable ({Why}); the built-in value is used instead.", what, why)));
    }

    /// <summary>The built-in values with every usable row laid over them.</summary>
    public static UiConfigDto Merge(
        IEnumerable<DisplayLabel> labelRows,
        IEnumerable<ThemeColor> colorRows,
        Action<string, string>? rejected = null)
    {
        var labels = UiConfigSeedData.Labels.ToDictionary(
            g => g.Key,
            g => new Dictionary<string, UiLabelDto>(g.Value, StringComparer.Ordinal),
            StringComparer.Ordinal);

        foreach (var row in labelRows)
        {
            var what = $"label {row.Group}/{row.Code}";
            if (string.IsNullOrWhiteSpace(row.Group) || string.IsNullOrWhiteSpace(row.Code)
                || string.IsNullOrWhiteSpace(row.Label))
            {
                rejected?.Invoke(what, "blank group, code or label");
                continue;
            }

            if (!UiConfigRules.IsTone(row.Tone))
            {
                rejected?.Invoke(what, $"unknown tone {row.Tone}");
                continue;
            }

            if (!UiConfigRules.IsIconName(row.IconName))
            {
                rejected?.Invoke(what, $"bad icon name {row.IconName}");
                continue;
            }

            if (!labels.TryGetValue(row.Group, out var group))
            {
                labels[row.Group] = group = new Dictionary<string, UiLabelDto>(StringComparer.Ordinal);
            }

            group[row.Code] = new UiLabelDto
            {
                Label = row.Label,
                Short = row.ShortLabel,
                Detail = row.Detail,
                Tone = row.Tone,
                Icon = row.IconName,
                Sort = row.SortOrder,
            };
        }

        var colors = new Dictionary<string, UiColorDto>(UiConfigSeedData.Colors, StringComparer.Ordinal);
        foreach (var row in colorRows)
        {
            if (string.IsNullOrWhiteSpace(row.Key)
                || !UiConfigRules.IsColor(row.LightValue) || !UiConfigRules.IsColor(row.DarkValue))
            {
                rejected?.Invoke($"colour {row.Key}", "not #AARRGGBB");
                continue;
            }

            colors[row.Key] = new UiColorDto(row.LightValue.ToUpperInvariant(), row.DarkValue.ToUpperInvariant());
        }

        return Build(
            labels.ToDictionary(g => g.Key, g => (IReadOnlyDictionary<string, UiLabelDto>)g.Value, StringComparer.Ordinal),
            colors);
    }

    private static UiConfigDto Build(
        IReadOnlyDictionary<string, IReadOnlyDictionary<string, UiLabelDto>> labels,
        IReadOnlyDictionary<string, UiColorDto> colors)
    {
        // Sorted before hashing, so the same content always gives the same version on every instance.
        var sortedLabels = labels
            .OrderBy(g => g.Key, StringComparer.Ordinal)
            .ToDictionary(
                g => g.Key,
                g => (IReadOnlyDictionary<string, UiLabelDto>)g.Value
                    .OrderBy(e => e.Key, StringComparer.Ordinal)
                    .ToDictionary(e => e.Key, e => e.Value, StringComparer.Ordinal),
                StringComparer.Ordinal);
        var sortedColors = colors
            .OrderBy(c => c.Key, StringComparer.Ordinal)
            .ToDictionary(c => c.Key, c => c.Value, StringComparer.Ordinal);

        var body = JsonSerializer.Serialize(new { sortedLabels, sortedColors }, VersionJson);
        var version = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(body)))[..16].ToLowerInvariant();

        return new UiConfigDto { Version = version, Labels = sortedLabels, Colors = sortedColors };
    }
}
