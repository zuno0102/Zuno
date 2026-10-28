using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.WorkChat.Common;

/// <summary>Who the signed-in user is in one business–worker conversation.</summary>
/// <param name="Role">Which side they are.</param>
/// <param name="UserId">Their user id, which a sent message is stamped with.</param>
/// <param name="DisplayName">What the other side sees as the sender.</param>
/// <param name="CounterpartUserId">The other side's user — who a sent message is addressed to.</param>
/// <param name="BusinessOwnerProfileId">The business in the pair.</param>
/// <param name="WorkerProfileId">The worker in the pair.</param>
/// <param name="OwnProfileId">
/// The caller's own profile id — what the other side uses to open this conversation, so it is
/// what a notification to them points at.
/// </param>
public readonly record struct WorkThreadParticipant(
    WorkThreadRole Role,
    Guid UserId,
    string DisplayName,
    Guid CounterpartUserId,
    Guid BusinessOwnerProfileId,
    Guid WorkerProfileId,
    Guid OwnProfileId);

/// <summary>
/// Settles who may read or write a business–worker conversation.
/// </summary>
/// <remarks>
/// <para>
/// One rule, used by every handler: the conversation belongs to a business and a worker who is on
/// its team — an active <see cref="Domain.Entities.BusinessWorker"/>. Accepting a job is what puts a
/// worker on the team, so this opens exactly when the business has accepted them and they have
/// agreed, and closes if either side ends the relationship. Nothing about bookings or hiring posts
/// changes; this only reads the relationship they already create.
/// </para>
/// <para>
/// The caller names the other side by profile id (a business names the worker, a worker names the
/// business); which side the caller is comes from their own account, never from the request.
/// Anyone else is refused outright rather than shown an empty thread.
/// </para>
/// </remarks>
public static class WorkThreadAccess
{
    public static async Task<WorkThreadParticipant> ResolveAsync(
        IApplicationDbContext dbContext,
        Guid userId,
        Guid counterpartProfileId,
        CancellationToken cancellationToken)
    {
        // As the business: the counterpart is one of its workers.
        var asBusiness = await dbContext.BusinessWorkers
            .Where(bw => bw.BusinessOwnerProfile.UserId == userId
                && bw.WorkerProfileId == counterpartProfileId
                && bw.AssignmentStatus == BusinessWorkerStatus.Active)
            .Select(bw => new
            {
                bw.BusinessOwnerProfileId,
                bw.WorkerProfileId,
                BusinessName = bw.BusinessOwnerProfile.BusinessName,
                WorkerUserId = bw.WorkerProfile.UserId,
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (asBusiness is not null)
        {
            return new WorkThreadParticipant(
                WorkThreadRole.Business,
                userId,
                asBusiness.BusinessName,
                asBusiness.WorkerUserId,
                asBusiness.BusinessOwnerProfileId,
                asBusiness.WorkerProfileId,
                asBusiness.BusinessOwnerProfileId);
        }

        // As the worker: the counterpart is a business whose team they are on.
        var asWorker = await dbContext.BusinessWorkers
            .Where(bw => bw.WorkerProfile.UserId == userId
                && bw.BusinessOwnerProfileId == counterpartProfileId
                && bw.AssignmentStatus == BusinessWorkerStatus.Active)
            .Select(bw => new
            {
                bw.BusinessOwnerProfileId,
                bw.WorkerProfileId,
                WorkerName = bw.WorkerProfile.User.FirstName + " " + bw.WorkerProfile.User.LastName,
                BusinessUserId = bw.BusinessOwnerProfile.UserId,
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (asWorker is not null)
        {
            return new WorkThreadParticipant(
                WorkThreadRole.Worker,
                userId,
                asWorker.WorkerName.Trim(),
                asWorker.BusinessUserId,
                asWorker.BusinessOwnerProfileId,
                asWorker.WorkerProfileId,
                asWorker.WorkerProfileId);
        }

        throw new UnauthorizedAccessException(
            "This conversation belongs to a business and a worker on its team.");
    }
}
