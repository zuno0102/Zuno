using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Specifications;
using Zuno.Domain.ValueObjects;

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

        // Orders finished and square. Counting in the database rather than in memory is what makes
        // this cheap enough to run on every completion and every payment — and why it must be
        // called after the caller has saved, not before.
        var settledOrders = await dbContext.Bookings
            .Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId)
            .CountAsync(BookingWageRules.CountsAsCompleted, cancellationToken);

        // Hiring the business did for itself. A post raised against an order is credited through
        // that order, so counting it here as well would credit one job twice.
        var standalonePosts = await dbContext.HiringPosts
            .Where(p => p.BusinessOwnerProfileId == businessOwnerProfileId
                && p.BookingId == null
                && p.WorkCompletedAt != null)
            .CountAsync(
                p => p.Applications.Any(a =>
                        a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
                    && !p.Applications.Any(a =>
                        a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                        && a.PaymentStatus != PaymentStatus.Paid),
                cancellationToken);

        profile.CompletedJobCount = settledOrders + standalonePosts;

        // Disputes count wherever they happened. Where the work came from has no bearing on a
        // worker saying they were never paid.
        profile.OpenDisputeCount = await dbContext.HiringPostApplications
            .CountAsync(
                a => a.HiringPost.BusinessOwnerProfileId == businessOwnerProfileId
                    && a.HiringPost.WorkCompletedAt != null
                    && a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                    && a.PaymentStatus == PaymentStatus.Disputed,
                cancellationToken);

        // Customer ratings come from the existing Rating table, which is per booking. Worker
        // ratings have no source yet — the two-sided review entity is a later phase — so the
        // worker average stays null and BusinessLevel treats "too few reviews" as clearing the
        // bar, rather than pinning every business at level 1 for want of a feature.
        var customerRatings = await dbContext.Ratings
            .Where(r => r.BusinessOwnerProfileId == businessOwnerProfileId)
            .Select(r => (decimal)r.Score)
            .ToListAsync(cancellationToken);

        profile.CustomerReviewCount = customerRatings.Count;
        profile.CustomerRatingAverage = customerRatings.Count > 0
            ? Math.Round(customerRatings.Average(), 2)
            : null;

        profile.Level = BusinessLevel.Calculate(
            platformSettings.Current.BusinessLevels,
            profile.CompletedJobCount,
            profile.CustomerRatingAverage,
            profile.CustomerReviewCount,
            profile.WorkerRatingAverage,
            profile.WorkerReviewCount,
            profile.OpenDisputeCount);

        profile.LevelRecalculatedAt = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
