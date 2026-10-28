using FluentAssertions;
using Zuno.Application.Common.Settings;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.UnitTests.Persistence;

/// <summary>A fresh database must hold one row per rule, at the value the code ships with.</summary>
public class PlatformSettingSeedDataTests
{
    [Fact]
    public void Seed_HasOneRowPerRule_AtItsDefault()
    {
        var rows = PlatformSettingSeedData.From(PlatformRules.Defaults);

        rows.Select(r => r.Key).Should().BeEquivalentTo(PlatformRules.Definitions.Select(d => d.Key));
        PlatformRules.From(rows.ToDictionary(r => r.Key, r => r.Value)).Should().Be(PlatformRules.Defaults);
        rows.Should().OnlyContain(r => r.Description.Length > 0);
    }

    [Fact]
    public void Seed_Ids_AreStable_SoMigrationsNeverChurn() =>
        PlatformSettingSeedData.From(PlatformRules.Defaults).Select(r => r.Id)
            .Should().Equal(PlatformSettingSeedData.From(PlatformRules.Defaults).Select(r => r.Id));
}
