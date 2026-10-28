using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>
/// What happens the moment a worker is hired onto a post — whichever side said the last yes.
/// </summary>
/// <remarks>
/// Hiring needs both sides to agree, and it is complete as soon as the second one does:
/// <list type="bullet">
/// <item>The worker applied, so the business accepting them is the second yes.</item>
/// <item>The business invited them, so the worker accepting is the second yes.</item>
/// </list>
/// Both paths end here, so a hire is recorded the same way however it came about. Callers have
/// already checked that hiring is open, a place is free and the worker's day is clear.
/// </remarks>
public static class HiringPostHire
{
    public static async Task CompleteAsync(
        HiringPostApplication application,
        IBusinessWorkerRepository businessWorkerRepository,
        IApplicationDbContext dbContext,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        application.ApplicationStatus = HiringPostApplicationStatus.Accepted;
        application.RespondedAt ??= now;
        application.WorkerRespondedAt ??= now;

        await AddToRosterAsync(application, businessWorkerRepository, now, cancellationToken);
        await AssignToLinkedBookingAsync(application, dbContext, now, cancellationToken);

        // Hiring may have filled the post.
        application.HiringPost.SyncStatusToStaffing();
    }

    /// <summary>
    /// Only now does the worker join the business's roster — being hired is what makes the
    /// relationship real, not an application or an offer.
    /// </summary>
    private static async Task AddToRosterAsync(
        HiringPostApplication application,
        IBusinessWorkerRepository businessWorkerRepository,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var businessProfileId = application.HiringPost.BusinessOwnerProfileId;
        var businessWorker = await businessWorkerRepository.GetByBusinessAndWorkerAsync(
            businessProfileId, application.WorkerProfileId, cancellationToken);

        if (businessWorker is null)
        {
            businessWorkerRepository.Add(new BusinessWorker
            {
                BusinessOwnerProfileId = businessProfileId,
                WorkerProfileId = application.WorkerProfileId,
                AssignmentStatus = BusinessWorkerStatus.Active,
                InvitedAt = application.RespondedAt ?? now,
                RespondedAt = now,
            });
        }
        else if (businessWorker.AssignmentStatus != BusinessWorkerStatus.Active)
        {
            businessWorker.AssignmentStatus = BusinessWorkerStatus.Active;
            businessWorker.RespondedAt = now;
        }
    }

    /// <summary>
    /// Puts a worker who was just hired onto the booking the post was raised for, if there is one.
    /// </summary>
    /// <remarks>
    /// Written directly rather than by sending <c>AssignWorkerCommand</c>, for one specific
    /// reason: that handler runs a clash check, and <c>WorkerScheduleService</c> counts accepted
    /// hiring-post applications as commitments. It would find the post this worker was hired onto a
    /// moment ago, see an exact overlap with itself, and refuse every single time. The real check
    /// has already run in the caller, for this worker over this same window.
    ///
    /// Nothing in here may throw. A problem on the booking side is not the worker's fault, and
    /// failing here would leave them un-hired after both sides had already said yes.
    /// </remarks>
    private static async Task AssignToLinkedBookingAsync(
        HiringPostApplication application,
        IApplicationDbContext dbContext,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        if (application.HiringPost.BookingId is not { } bookingId)
        {
            return;
        }

        var booking = await dbContext.Bookings
            .Include(b => b.WorkerAssignments)
            .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

        // The order was called off or finished in the meantime.
        if (booking is null
            || booking.BookingStatus is BookingStatus.Cancelled or BookingStatus.Completed)
        {
            return;
        }

        // Already on it — added by hand in the meantime. Nothing to write, and the hire still stands.
        if (booking.WorkerAssignments.Any(a => a.WorkerProfileId == application.WorkerProfileId))
        {
            return;
        }

        // Deliberately no headcount limit. The post already said how many people the business
        // wanted and stopped taking workers once that many were hired — checking a second, unrelated
        // number off the service definition would quietly drop someone the business had just hired.

        // Accepted, not Assigned: both sides have agreed already. Assigned would put the same job back
        // in front of the worker to accept a second time.
        dbContext.BookingWorkerAssignments.Add(new BookingWorkerAssignment
        {
            BookingId = booking.Id,
            WorkerProfileId = application.WorkerProfileId,
            AssignmentStatus = BookingWorkerAssignmentStatus.Accepted,
            RespondedAt = now,
        });

        // The order's own status is untouched. Staffing is its own track, worked out from these
        // assignments — hiring someone is not the business confirming the order.
    }
}
