using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Holds the rules from the <c>platform_settings</c> and <c>level_definitions</c> tables in memory, one copy per instance.
/// </summary>
/// <remarks>
/// A singleton: the rules are swapped in whole as an immutable record, so a request never sees half of
/// one refresh and half of another, and reading them needs no lock and no database round trip. Until
/// the first load completes it serves the built-in defaults, which are the values the table is seeded
/// with — so start-up behaves exactly as a loaded table would.
/// </remarks>
public sealed class PlatformSettingsStore(
    IServiceScopeFactory scopeFactory,
    ILogger<PlatformSettingsStore> logger) : IPlatformSettings
{
    private PlatformRules _current = PlatformRules.Defaults;

    public PlatformRules Current => Volatile.Read(ref _current);

    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ZunoDbContext>();

        var rows = await dbContext.PlatformSettings
            .AsNoTracking()
            .Select(s => new { s.Key, s.Value })
            .ToDictionaryAsync(s => s.Key, s => s.Value, StringComparer.OrdinalIgnoreCase, cancellationToken);

        var rungs = await dbContext.LevelDefinitions
            .AsNoTracking()
            .Select(l => new
            {
                l.Audience,
                Rung = new LevelRung(l.Level, l.Name, l.MinCompletedJobs, l.MinRating, l.MinBusinesses, l.MinAnsweredRate),
            })
            .ToListAsync(cancellationToken);

        void Rejected(string key, string raw) =>
            logger.LogWarning(
                "Platform setting {Key} is unusable ({Value}); the built-in default is used instead.",
                key, raw);

        var rules = PlatformRules.From(rows, Rejected);
        foreach (var audience in Enum.GetValues<LevelAudience>())
        {
            rules = rules.WithLevelRungs(
                audience, [.. rungs.Where(r => r.Audience == audience).Select(r => r.Rung)], Rejected);
        }

        Volatile.Write(ref _current, rules);
    }
}
