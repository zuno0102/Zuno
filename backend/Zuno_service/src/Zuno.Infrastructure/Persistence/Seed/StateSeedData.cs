using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

public static class StateSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    public static Guid IdFor(string stateName) => DeterministicGuid.From($"state:{stateName}");

    public static State[] All =>
        IndiaLocationData.StatesAndDistricts.Keys
            .Select(name => new State
            {
                Id = IdFor(name),
                Name = name,
                CreatedDate = SeedDate,
                IsDeleted = false,
            })
            .ToArray();
}
