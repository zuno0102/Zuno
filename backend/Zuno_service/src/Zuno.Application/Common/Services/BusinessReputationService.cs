using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Specifications;

namespace Zuno.Application.Common.Services;

/// <inheritdoc />
public class BusinessReputationService(
    IApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider,
    IPlatformSettings platformSettings) : IBusinessReputationService
{
    public async Task RecalculateAndSaveAsync(
        Guid businessOwnerProfileId,
        CancellationToken cancellationToken = default)
    {
        var profile = await dbContext.BusinessOwnerProfiles
            .FirstOrDefaultAsync(p => p.Id == businessOwnerProfileId, cancellationToken);

        if (profile is null)
        {
            return;
        }

        await RecalculateAsync([profile], cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task RecalculateAsync(
        IReadOnlyList<BusinessOwnerProfile> profiles,
        CancellationToken cancellationToken = default)
    {
        if (profiles.Count == 0)
        {
            return;
        }

        var ids = profiles.Select(p => p.Id).ToList();

        // Orders finished and square. Counting in the database rather than in memory is what makes
        // this cheap enough to run on every completion and every payment — and why it must be
        // called after the caller has saved, not before.
        var settledOrders = await dbContext.Bookings
            .Where(b => ids.Contains(b.BusinessOwnerProfileId))
            .Where(BookingWageRules.CountsAsCompleted)
            .GroupBy(b => b.BusinessOwnerProfileId)
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Id, g => g.Count, cancellationToken);

        // Hiring the business did for itself. A post raised against an order is credited through
        // that order, so counting it here as well would credit one job twice.
        var standalonePosts = await dbContext.HiringPosts
            .Where(p => ids.Contains(p.BusinessOwnerProfileId)
                && p.BookingId == null
                && p.WorkCompletedAt != null)
            .Where(p => p.Applications.Any(a =>
                    a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
                && !p.Applications.Any(a =>
                    a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                    && a.PaymentStatus != PaymentStatus.Paid))
            .GroupBy(p => p.BusinessOwnerProfileId)
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Id, g => g.Count, cancellationToken);

        // Disputes count wherever they happened. Where the work came from has no bearing on a
        // worker saying they were never paid.
        var disputes = await dbContext.HiringPostApplications
            .Where(a => ids.Contains(a.HiringPost.BusinessOwnerProfileId)
                && a.HiringPost.WorkCompletedAt != null
                && a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                && a.PaymentStatus == PaymentStatus.Disputed)
            .GroupBy(a => a.HiringPost.BusinessOwnerProfileId)
            .Select(g => new { Id = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Id, g => g.Count, cancellationToken);

        // Customer ratings of Service orders, as a total and a count — what the fair average is made
        // from. Worker ratings have no source yet (the two-sided review is a later phase), so the worker
        // average stays null and the level treats "too few reviews" as clearing the bar.
        var ratings = await dbContext.Ratings
            .Where(r => ids.Contains(r.BusinessOwnerProfileId))
            .GroupBy(r => r.BusinessOwnerProfileId)
            .Select(g => new { Id = g.Key, Sum = g.Sum(r => (decimal)r.Score), Count = g.Count() })
            .ToDictionaryAsync(g => g.Id, cancellationToken);

        var rules = platformSettings.Current;
        var now = dateTimeProvider.UtcNow;

        foreach (var profile in profiles)
        {
            profile.CompletedJobCount = settledOrders.GetValueOrDefault(profile.Id)
                + standalonePosts.GetValueOrDefault(profile.Id);
            profile.OpenDisputeCount = disputes.GetValueOrDefault(profile.Id);

            var rated = ratings.GetValueOrDefault(profile.Id);
            profile.ServiceRatingSum = rated?.Sum ?? 0m;
            profile.ServiceRatingCount = rated?.Count ?? 0;

            BusinessStanding.Apply(profile, rules, now);
        }
    }

    public async Task RecalculateServiceRatingAsync(
        Guid businessServiceId,
        CancellationToken cancellationToken = default)
    {
        var service = await dbContext.BusinessServices
            .FirstOrDefaultAsync(s => s.Id == businessServiceId, cancellationToken);

        if (service is null)
        {
            return;
        }

        var ratings = dbContext.Ratings.Where(r => r.BusinessServiceId == businessServiceId);
        service.RatingCount = await ratings.CountAsync(cancellationToken);
        service.RatingSum = await ratings.SumAsync(r => (decimal)r.Score, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
