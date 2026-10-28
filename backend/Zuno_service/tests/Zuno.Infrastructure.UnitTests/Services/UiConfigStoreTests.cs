using FluentAssertions;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>Labels and colours come from their tables; a bad row can never blank out the app.</summary>
public class UiConfigStoreTests
{
    private static readonly List<DisplayLabel> NoLabels = [];
    private static readonly List<ThemeColor> NoColors = [];

    [Fact]
    public void Merge_EmptyTables_GivesTheBuiltInValues()
    {
        var config = UiConfigStore.Merge(NoLabels, NoColors);

        config.Labels["VacancyApplication.Worker"]["Hired"].Label.Should().Be("Hired");
        config.Colors["status.success"].Light.Should().Be("#FF1B7F42");
    }

    [Fact]
    public void Merge_AGoodLabelRow_ChangesThatLabelOnly()
    {
        var config = UiConfigStore.Merge(
            [new DisplayLabel { Group = "VacancyApplication.Worker", Code = "Hired", Label = "You got the job", Tone = "success" }],
            NoColors);

        config.Labels["VacancyApplication.Worker"]["Hired"].Label.Should().Be("You got the job");
        config.Labels["VacancyApplication.Worker"]["Shortlisted"].Label.Should().Be("Shortlisted");
    }

    [Fact]
    public void Merge_ANewGroupInTheTable_IsServed()
    {
        var config = UiConfigStore.Merge(
            [new DisplayLabel { Group = "Brand.New", Code = "A", Label = "Something new", SortOrder = 3 }],
            NoColors);

        config.Labels["Brand.New"]["A"].Should().BeEquivalentTo(new { Label = "Something new", Sort = 3 });
    }

    [Theory]
    [InlineData("", "Hired", "x", null, null)]
    [InlineData("VacancyApplication.Worker", "Hired", " ", null, null)]       // blank label
    [InlineData("VacancyApplication.Worker", "Hired", "x", "purple", null)]   // unknown tone
    [InlineData("VacancyApplication.Worker", "Hired", "x", null, "Bad Icon!")]
    public void Merge_AnUnusableLabelRow_KeepsTheBuiltInAndReportsIt(
        string group, string code, string label, string? tone, string? icon)
    {
        var rejected = new List<string>();

        var config = UiConfigStore.Merge(
            [new DisplayLabel { Group = group, Code = code, Label = label, Tone = tone, IconName = icon }],
            NoColors,
            (what, _) => rejected.Add(what));

        config.Labels["VacancyApplication.Worker"]["Hired"].Label.Should().Be("Hired");
        rejected.Should().ContainSingle();
    }

    [Fact]
    public void Merge_AGoodColourRow_ChangesThatColour()
    {
        var config = UiConfigStore.Merge(
            NoLabels,
            [new ThemeColor { Key = "status.success", LightValue = "#ff00aa00", DarkValue = "#FF00CC00" }]);

        config.Colors["status.success"].Light.Should().Be("#FF00AA00");
        config.Colors["status.success"].Dark.Should().Be("#FF00CC00");
    }

    [Theory]
    [InlineData("#FF00AA0")]     // seven digits
    [InlineData("00AA00FF")]     // no hash
    [InlineData("#GG00AA00")]    // not hex
    [InlineData("red")]
    public void Merge_AnUnusableColour_KeepsTheBuiltIn(string value)
    {
        var config = UiConfigStore.Merge(
            NoLabels,
            [new ThemeColor { Key = "status.success", LightValue = value, DarkValue = "#FF00CC00" }]);

        config.Colors["status.success"].Light.Should().Be("#FF1B7F42");
    }

    [Fact]
    public void Version_ChangesWithTheContent_AndOnlyWithIt()
    {
        var a = UiConfigStore.Merge(NoLabels, NoColors).Version;
        var b = UiConfigStore.Merge(NoLabels, NoColors).Version;
        var c = UiConfigStore.Merge(
            NoLabels, [new ThemeColor { Key = "status.success", LightValue = "#FF000000", DarkValue = "#FF000000" }]).Version;

        a.Should().Be(b);
        c.Should().NotBe(a);
    }
}
