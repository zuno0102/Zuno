using FluentAssertions;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.UnitTests.Persistence;

public class LevelDefinitionSeedDataTests
{
    [Fact]
    public void EveryRung_HasItsOwnStableId() =>
        LevelDefinitionSeedData.Rows.Select(r => r.Id).Should().OnlyHaveUniqueItems().And.NotContain(Guid.Empty);

    [Theory]
    [InlineData(LevelAudience.Business)]
    [InlineData(LevelAudience.Worker)]
    public void EachAudience_IsSeededWithAUsableLadder_MatchingTheBuiltInOne(LevelAudience audience)
    {
        var rungs = LevelDefinitionSeedData.Rows
            .Where(r => r.Audience == audience)
            .Select(r => new LevelRung(r.Level, r.Name, r.MinCompletedJobs, r.MinRating, r.MinBusinesses, r.MinAnsweredRate))
            .ToList();
        var builtIn = audience == LevelAudience.Business ? LevelLadder.BusinessDefaults : LevelLadder.WorkerDefaults;

        LevelLadder.Problem(rungs).Should().BeNull();
        rungs.Should().Equal(builtIn.Rungs);
    }
}
