using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Services;

/// <inheritdoc />
/// <remarks>
/// Rent figures are copied only when the Rent API answered. When it did not — not configured, asleep,
/// broken — every business keeps the Rent figures it already had: a missed reading is "unknown", and
/// zeroing it would quietly cost honest businesses their level. Levels are recalculated either way,
/// because the gradual steps depend on time passing, not only on new events.
/// </remarks>
public class BusinessReputationSync(
    IApplicationDbContext dbContext,
    IRentReputationClient rentClient,
    IBusinessReputationService reputationService,
    IDateTimeProvider dateTimeProvider,
    IOptions<ReputationSyncSettings> settings) : IBusinessReputationSync
{
    public async Task<int> RunAsync(CancellationToken cancellationToken)
    {
        var rent = await rentClient.GetAllAsync(cancellationToken);
        var rentByOwner = rent?
            .GroupBy(r => r.OwnerUserId)
            .ToDictionary(g => g.Key, g => g.First());

        var batchSize = settings.Value.BatchSize;
        var updated = 0;
        Guid? lastId = null;

        // Keyset paging by id: each batch starts after the last one, so a pass over millions of rows
        // never re-reads or skips one, and memory holds only one batch at a time.
        while (true)
        {
            IQueryable<BusinessOwnerProfile> query = dbContext.BusinessOwnerProfiles;
            if (lastId is { } after)
            {
                query = query.Where(p => p.Id.CompareTo(after) > 0);
            }

            var batch = await query
                .OrderBy(p => p.Id)
                .Take(batchSize)
                .ToListAsync(cancellationToken);

            if (batch.Count == 0)
            {
                break;
            }

            if (rentByOwner is not null)
            {
                CopyRentFigures(batch, rentByOwner, dateTimeProvider.UtcNow);
            }

            await reputationService.RecalculateAsync(batch, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);

            updated += batch.Count;
            lastId = batch[^1].Id;

            if (batch.Count < batchSize)
            {
                break;
            }
        }

        return updated;
    }

    /// <summary>Each business's Rent figures from the reading; a business with no Rent record has none.</summary>
    private static void CopyRentFigures(
        List<BusinessOwnerProfile> batch,
        Dictionary<Guid, RentReputation> rentByOwner,
        DateTimeOffset now)
    {
        foreach (var profile in batch)
        {
            var rent = rentByOwner.GetValueOrDefault(profile.UserId);
            profile.RentRatingSum = rent?.RatingSum ?? 0m;
            profile.RentRatingCount = rent?.RatingCount ?? 0;
            profile.RentSuccessfulOrders = rent?.SuccessfulOrders ?? 0;
            profile.RentReputationAt = now;
        }
    }
}
