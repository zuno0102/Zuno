using FluentAssertions;
using Zuno.Application.Modules.Catalog.Common;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.UnitTests.Persistence;

/// <summary>The built-in labels and colours: valid, seeded once each, and identical to the app's copy.</summary>
public class UiConfigSeedDataTests
{
    [Fact]
    public void EverySeedRow_HasItsOwnStableId()
    {
        UiConfigSeedData.LabelRows.Select(r => r.Id).Should().OnlyHaveUniqueItems();
        UiConfigSeedData.ColorRows.Select(r => r.Id).Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void EveryLabel_IsUsable()
    {
        foreach (var row in UiConfigSeedData.LabelRows)
        {
            row.Label.Should().NotBeNullOrWhiteSpace($"{row.Group}/{row.Code}");
            UiConfigRules.IsTone(row.Tone).Should().BeTrue($"{row.Group}/{row.Code} tone {row.Tone}");
            UiConfigRules.IsIconName(row.IconName).Should().BeTrue($"{row.Group}/{row.Code} icon {row.IconName}");
        }
    }

    [Fact]
    public void EveryColour_IsAARRGGBB() =>
        UiConfigSeedData.ColorRows.Should().OnlyContain(r =>
            UiConfigRules.IsColor(r.LightValue) && UiConfigRules.IsColor(r.DarkValue));

    [Theory]
    [InlineData("status.success")]
    [InlineData("status.progress")]
    [InlineData("status.waiting")]
    [InlineData("status.danger")]
    public void EveryTone_HasAColour(string key) =>
        UiConfigSeedData.Colors.Should().ContainKey(key);

    /// <remarks>
    /// The app bundles the same files so it can paint before it has ever reached the server. Copy
    /// backend/src/Zuno.Infrastructure/Persistence/Seed/UiConfig/*.json to mobile/assets/ui_config/
    /// whenever one changes.
    /// </remarks>
    [Fact]
    public void TheAppsBundledCopy_MatchesTheseFiles()
    {
        var appCopy = FindAppCopy();
        if (appCopy is null)
        {
            return; // Not a full checkout (a container build, say); nothing to compare with.
        }

        var appFiles = Directory.GetFiles(appCopy, "*.json").Select(Path.GetFileName).Order().ToList();
        appFiles.Should().Equal(UiConfigSeedData.Files.Keys.Order(), "the app must bundle exactly these files");

        foreach (var (name, text) in UiConfigSeedData.Files)
        {
            Normalise(File.ReadAllText(Path.Combine(appCopy, name)))
                .Should().Be(Normalise(text), $"mobile/assets/ui_config/{name} is out of date");
        }
    }

    private static string Normalise(string text) => text.Replace("\r\n", "\n").Trim();

    private static string? FindAppCopy()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "mobile", "assets", "ui_config");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }
}
