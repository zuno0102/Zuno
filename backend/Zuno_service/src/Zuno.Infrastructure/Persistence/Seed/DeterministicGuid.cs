using System.Security.Cryptography;
using System.Text;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// Generates a stable Guid from a plain-text seed so large reference-data tables (states,
/// districts) can be authored as name lists instead of hand-typed literal Guids per row.
/// The same seed string always produces the same Guid, so re-running codegen/migrations
/// against unchanged names never churns ids.
/// </summary>
internal static class DeterministicGuid
{
    public static Guid From(string seed) => new(MD5.HashData(Encoding.UTF8.GetBytes(seed)));
}
