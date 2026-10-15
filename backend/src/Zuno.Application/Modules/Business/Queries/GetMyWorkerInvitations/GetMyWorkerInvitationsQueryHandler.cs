using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Queries.GetMyWorkerInvitations;

public class GetMyWorkerInvitationsQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext,
    IBusinessWorkerRepository businessWorkerRepository)
    : IRequestHandler<GetMyWorkerInvitationsQuery, List<WorkerInvitationDto>>
{
    public async Task<List<WorkerInvitationDto>> Handle(GetMyWorkerInvitationsQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        // Invitations still waiting, and the businesses already joined.
        //
        // It used to return only the waiting ones, so accepting an invitation made it vanish with
        // nothing to show for it: no screen in the app named the businesses a worker had agreed to
        // work for, and the only sign the tap had done anything was the row disappearing.
        //
        // Declined and removed are deliberately left out. Those are finished business, and a list of
        // things a worker said no to is a list nobody needs.
        var all = await businessWorkerRepository.GetByWorkerIdAsync(
            workerProfile.Id, status: null, cancellationToken);

        return all
            .Where(i => i.AssignmentStatus is BusinessWorkerStatus.Invited
                or BusinessWorkerStatus.Active)
            .Select(i => i.ToInvitationDto())
            .ToList();
    }
}
