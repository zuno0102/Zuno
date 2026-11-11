using System.Security.Cryptography;
using System.Text;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Infrastructure.Persistence.Seed;

/// <summary>
/// States and districts with <b>the same ids as the Service module</b>: both derive each id from the
/// same name list with the same formula, so a district picked in the app means the same place in
/// either database without the two ever talking to each other.
/// </summary>
public static class LocationSeedData
{
    public static Guid StateId(string stateName) => From($"state:{stateName}");

    public static Guid DistrictId(string stateName, string districtName) => From($"district:{stateName}:{districtName}");

    public static RefState[] States =>
        IndiaLocationData.StatesAndDistricts.Keys
            .Select(name => new RefState { Id = StateId(name), Name = name })
            .ToArray();

    public static RefDistrict[] Districts =>
        IndiaLocationData.StatesAndDistricts
            .SelectMany(state => state.Value.Select(district => new RefDistrict
            {
                Id = DistrictId(state.Key, district),
                Name = district,
                StateId = StateId(state.Key),
            }))
            .ToArray();

    // Must stay byte-for-byte the Service module's DeterministicGuid.From.
    private static Guid From(string seed) => new(MD5.HashData(Encoding.UTF8.GetBytes(seed)));
}
