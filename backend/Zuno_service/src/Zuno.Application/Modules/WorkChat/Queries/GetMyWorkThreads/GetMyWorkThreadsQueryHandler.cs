using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.WorkChat.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.WorkChat.Queries.GetMyWorkThreads;

public class GetMyWorkThreadsQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetMyWorkThreadsQuery, List<WorkThreadDto>>
{
    public async Task<List<WorkThreadDto>> Handle(
        GetMyWorkThreadsQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Both sides are checked rather than the role claim: the team relationship is the authority
        // on who is party to a conversation, as the booking is for booking threads.
        var rows = await dbContext.BusinessWorkers
            .Where(bw => bw.AssignmentStatus == BusinessWorkerStatus.Active
                && (bw.BusinessOwnerProfile.UserId == userId || bw.WorkerProfile.UserId == userId))
            .Select(bw => new
            {
                bw.BusinessOwnerProfileId,
                bw.WorkerProfileId,
                IAmBusiness = bw.BusinessOwnerProfile.UserId == userId,
                BusinessName = bw.BusinessOwnerProfile.BusinessName,
                BusinessLogoUrl = bw.BusinessOwnerProfile.LogoUrl,
                WorkerName = bw.WorkerProfile.User.FirstName + " " + bw.WorkerProfile.User.LastName,
                WorkerPhotoUrl = bw.WorkerProfile.PhotoUrl ?? bw.WorkerProfile.User.ProfileImageUrl,
                Last = dbContext.WorkMessages
                    .Where(m => m.BusinessOwnerProfileId == bw.BusinessOwnerProfileId
                        && m.WorkerProfileId == bw.WorkerProfileId)
                    .OrderByDescending(m => m.CreatedDate)
                    .Select(m => new { m.Body, m.CreatedDate, m.SenderRole })
                    .FirstOrDefault(),
                UnreadFromWorker = dbContext.WorkMessages.Count(m =>
                    m.BusinessOwnerProfileId == bw.BusinessOwnerProfileId
                    && m.WorkerProfileId == bw.WorkerProfileId
                    && m.SenderRole == WorkThreadRole.Worker
                    && m.ReadAt == null),
                UnreadFromBusiness = dbContext.WorkMessages.Count(m =>
                    m.BusinessOwnerProfileId == bw.BusinessOwnerProfileId
                    && m.WorkerProfileId == bw.WorkerProfileId
                    && m.SenderRole == WorkThreadRole.Business
                    && m.ReadAt == null),
            })
            .ToListAsync(cancellationToken);

        return
        [
            .. rows
                // A pair nobody has written with is not a conversation yet; it appears the moment
                // either side says something, started from a job or a crew row.
                .Where(r => r.Last is not null)
                .Select(r =>
                {
                    var mine = r.IAmBusiness ? WorkThreadRole.Business : WorkThreadRole.Worker;
                    return new WorkThreadDto
                    {
                        CounterpartId = r.IAmBusiness ? r.WorkerProfileId : r.BusinessOwnerProfileId,
                        CounterpartName = r.IAmBusiness ? r.WorkerName.Trim() : r.BusinessName,
                        CounterpartImageUrl = r.IAmBusiness ? r.WorkerPhotoUrl : r.BusinessLogoUrl,
                        LastMessage = r.Last!.Body,
                        LastMessageAt = r.Last.CreatedDate,
                        LastMessageIsMine = r.Last.SenderRole == mine,
                        UnreadCount = r.IAmBusiness ? r.UnreadFromWorker : r.UnreadFromBusiness,
                    };
                })
                // Newest activity first.
                .OrderByDescending(t => t.LastMessageAt),
        ];
    }
}
