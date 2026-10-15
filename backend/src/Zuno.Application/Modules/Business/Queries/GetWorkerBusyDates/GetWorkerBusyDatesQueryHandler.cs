using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Queries.GetWorkerBusyDates;

public class GetWorkerBusyDatesQueryHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IWorkerScheduleService workerScheduleService)
    : IRequestHandler<GetWorkerBusyDatesQuery, List<WorkerBusyPeriodDto>>
{
    public async Task<List<WorkerBusyPeriodDto>> Handle(
        GetWorkerBusyDatesQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        // Only for this business's own crew.
        //
        // Without this the route answered for ANY worker id, to ANY signed-in business owner. The
        // role check on the controller did not help: every attacker here already holds a
        // legitimate business account, and worker ids travel in the open — they are in the crew
        // list of every order a worker is on.
        //
        // What leaked is when somebody is working, which is when they are working for a
        // competitor. A business can read its own crew's diary because it has to, to avoid
        // double-booking them; it has no reason to read anybody else's.
        var membership = await businessWorkerRepository.GetByBusinessAndWorkerAsync(
            businessProfile.Id, request.WorkerProfileId, cancellationToken);

        if (membership is null)
        {
            // Not found rather than forbidden: a refusal would confirm that the guessed id belongs
            // to a real worker, which is already more than a stranger should learn.
            throw new EntityNotFoundException(nameof(WorkerProfile), request.WorkerProfileId);
        }

        // The same call that decides the availability badge on the workers list, so a worker
        // shown as free can never open onto a list of dates, and one shown as booked can never
        // open onto an empty one.
        var commitments = await workerScheduleService.GetCommitmentsAsync(
            [request.WorkerProfileId], cancellationToken);

        return commitments
            .Select(c => new WorkerBusyPeriodDto
            {
                StartsAt = c.StartsAt,
                EndsAt = c.EndsAt,
            })
            .ToList();
    }
}
