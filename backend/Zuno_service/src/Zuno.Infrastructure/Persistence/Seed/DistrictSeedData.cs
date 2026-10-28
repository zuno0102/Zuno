using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

public static class DistrictSeedData
{
    private static readonly DateTimeOffset SeedDate = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    public static Guid IdFor(string stateName, string districtName) =>
        DeterministicGuid.From($"district:{stateName}:{districtName}");

    public static District[] All =>
        IndiaLocationData.StatesAndDistricts
            .SelectMany(stateEntry => stateEntry.Value.Select(districtName => new District
            {
                Id = IdFor(stateEntry.Key, districtName),
                Name = districtName,
                CentreLatitude = DistrictCentroidData.For(stateEntry.Key, districtName)?.Latitude,
                CentreLongitude = DistrictCentroidData.For(stateEntry.Key, districtName)?.Longitude,
                StateId = StateSeedData.IdFor(stateEntry.Key),
                CreatedDate = SeedDate,
                IsDeleted = false,
            }))
            .ToArray();
}
