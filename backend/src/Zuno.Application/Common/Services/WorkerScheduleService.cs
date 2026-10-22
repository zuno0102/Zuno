using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Services;

/// <summary>
/// Finds clashes in a worker's diary across both hiring posts and bookings.
/// </summary>
public class WorkerScheduleService(IApplicationDbContext dbContext) : IWorkerScheduleService
{
    /// <summary>
    /// Used when a booking's service carries no estimate. Two hours is the same assumption a
    /// hiring post starts from, so an unspecified job still occupies a believable block rather
    /// than an instant that clashes with nothing.
    /// </summary>
    private const int DefaultJobMinutes = 120;

    public int TravelBufferMinutes => 30;

    /// <summary>A job as it sits in a worker's day, whichever module it came from.</summary>
    /// <remarks>
    /// <paramref name="Title"/> and <paramref name="Source"/> exist to phrase a clash message and
    /// go no further: they are dropped before this leaves the service, because a worker's diary
    /// spans every business they serve.
    /// </remarks>
    /// <param name="IsUnfinished">Work that has begun and that nobody has marked completed.</param>
    private sealed record Commitment(
        Guid WorkerProfileId,
        string Source,
        string Title,
        DateTimeOffset StartsAt,
        DateTimeOffset EndsAt,
        bool IsUnfinished);

    public async Task<WorkerScheduleConflict?> FindConflictAsync(
        Guid workerProfileId,
        DateTimeOffset startsAt,
        DateTimeOffset endsAt,
        Guid? excludeHiringPostId = null,
        Guid? excludeBookingId = null,
        CancellationToken cancellationToken = default)
    {
        var commitments = await LoadCommitmentsAsync(
            [workerProfileId], excludeHiringPostId, excludeBookingId, cancellationToken);

        // Before any date arithmetic: a job already under way and not yet closed holds the worker
        // whatever the calendar says. Work that has started has no reliable end — a two-hour
        // booking can run five — so the times cannot be trusted to say they are free.
        foreach (var job in commitments)
        {
            if (job.IsUnfinished)
            {
                return new WorkerScheduleConflict(
                    WorkerScheduleConflictKind.Unfinished,
                    job.Source, job.Title, job.StartsAt, job.EndsAt, 0);
            }
        }

        // Straight collisions next: a worker double-booked at the same hour is a worse problem
        // than one with a tight journey, and deserves the clearer message.
        foreach (var job in commitments)
        {
            if (startsAt < job.EndsAt && job.StartsAt < endsAt)
            {
                return new WorkerScheduleConflict(
                    WorkerScheduleConflictKind.Overlap,
                    job.Source, job.Title, job.StartsAt, job.EndsAt, 0);
            }
        }

        foreach (var job in commitments)
        {
            // Whichever job comes first, the gap is the distance between one ending and the
            // next beginning.
            var gap = job.EndsAt <= startsAt
                ? (startsAt - job.EndsAt).TotalMinutes
                : (job.StartsAt - endsAt).TotalMinutes;

            // Inclusive: a gap of exactly the buffer is refused, not allowed. Thirty minutes
            // measured on a map is not thirty minutes with a bag to pack and traffic to sit in,
            // so the worker has to clear the buffer rather than merely match it.
            if (gap <= TravelBufferMinutes)
            {
                return new WorkerScheduleConflict(
                    WorkerScheduleConflictKind.TooTight,
                    job.Source, job.Title, job.StartsAt, job.EndsAt, (int)Math.Floor(gap));
            }
        }

        return null;
    }

    private async Task<List<Commitment>> LoadCommitmentsAsync(
        IReadOnlyCollection<Guid> workerProfileIds,
        Guid? excludeHiringPostId,
        Guid? excludeBookingId,
        CancellationToken cancellationToken)
    {
        // Only accepted work holds a worker. A pending offer they have not answered is not yet a
        // commitment, and a completed job releases them even if its window has not elapsed.
        var hiringJobs = await dbContext.HiringPostApplications
            .Where(a => workerProfileIds.Contains(a.WorkerProfileId)
                && a.ApplicationStatus == HiringPostApplicationStatus.Accepted
                && a.HiringPost.WorkCompletedAt == null
                && (excludeHiringPostId == null || a.HiringPostId != excludeHiringPostId))
            .Select(a => new
            {
                a.HiringPost.Title,
                a.HiringPost.EventDate,
                a.HiringPost.DurationMinutes,
                a.WorkerProfileId,
                a.HiringPost.WorkStartedAt,
                a.HiringPost.WorkCompletedAt,
            })
            .ToListAsync(cancellationToken);

        var bookingJobs = await dbContext.BookingWorkerAssignments
            .Where(a => workerProfileIds.Contains(a.WorkerProfileId)
                && (a.AssignmentStatus == BookingWorkerAssignmentStatus.Assigned
                    || a.AssignmentStatus == BookingWorkerAssignmentStatus.Accepted)
                && a.Booking.CompletedAt == null
                && a.Booking.BookingStatus != BookingStatus.Cancelled
                && (excludeBookingId == null || a.BookingId != excludeBookingId))
            .Select(a => new
            {
                a.Booking.ScheduledDate,
                ServiceName = a.Booking.BusinessService.Name,
                VariantMinutes = a.Booking.BusinessServiceVariant != null
                    ? a.Booking.BusinessServiceVariant.EstimatedDurationMinutes
                    : null,
                ServiceMinutes = a.Booking.BusinessService.EstimatedDurationMinutes,
                a.WorkerProfileId,
                a.Booking.WorkStartedAt,
                a.Booking.CompletedAt,
            })
            .ToListAsync(cancellationToken);

        // End times are computed rather than stored, so the arithmetic happens here rather than
        // in SQL. The candidate set is one worker's live jobs, so it stays small.
        var commitments = hiringJobs
            .Select(j => new Commitment(
                j.WorkerProfileId,
                "hiring post",
                j.Title,
                j.EventDate,
                j.EventDate.AddMinutes(j.DurationMinutes),
                j.WorkStartedAt is not null && j.WorkCompletedAt is null))
            .ToList();

        commitments.AddRange(bookingJobs.Select(j =>
        {
            var minutes = j.VariantMinutes ?? j.ServiceMinutes ?? DefaultJobMinutes;
            return new Commitment(
                j.WorkerProfileId,
                "booking",
                j.ServiceName,
                j.ScheduledDate,
                j.ScheduledDate.AddMinutes(minutes),
                j.WorkStartedAt is not null && j.CompletedAt is null);
        }));

        return commitments;
    }

    public async Task<IReadOnlyList<WorkerCommitment>> GetCommitmentsAsync(
        IReadOnlyCollection<Guid> workerProfileIds,
        CancellationToken cancellationToken = default)
    {
        if (workerProfileIds.Count == 0)
        {
            return [];
        }

        var commitments = await LoadCommitmentsAsync(
            workerProfileIds, null, null, cancellationToken);

        // Soonest first: a diary is read forwards.
        return commitments
            .OrderBy(c => c.StartsAt)
            .ThenBy(c => c.EndsAt)
            .Select(c => new WorkerCommitment(c.WorkerProfileId, c.StartsAt, c.EndsAt))
            .ToList();
    }
}
