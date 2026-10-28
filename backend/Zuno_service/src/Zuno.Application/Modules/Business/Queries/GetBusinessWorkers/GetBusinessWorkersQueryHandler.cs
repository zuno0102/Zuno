using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessWorkers;

public class GetBusinessWorkersQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessWorkerRepository businessWorkerRepository,
    IWorkerScheduleService workerScheduleService)
    : IRequestHandler<GetBusinessWorkersQuery, List<BusinessWorkerDto>>
{
    public async Task<List<BusinessWorkerDto>> Handle(GetBusinessWorkersQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var workers = await businessWorkerRepository.GetByBusinessIdAsync(businessProfile.Id, cancellationToken);

        var workerProfileIds = workers.Select(w => w.WorkerProfileId).Distinct().ToList();

        // Read from the schedule service, which is also what the worker's schedule screen lists.
        // These used to be worked out from separate queries, and disagreed in both directions:
        // a worker held only by a hiring post read as free while their schedule showed jobs, and
        // a worker on a cancelled booking read as booked forever while their schedule was empty.
        // One source means the badge and the dates behind it always tell the same story.
        var commitments = await workerScheduleService.GetCommitmentsAsync(
            workerProfileIds, cancellationToken);

        var now = dateTimeProvider.UtcNow;

        // "At work" — on site this minute — outranks "Booked", which is anything still to come.
        var atWork = commitments
            .Where(c => c.StartsAt <= now && now < c.EndsAt)
            .Select(c => c.WorkerProfileId)
            .ToHashSet();

        var booked = commitments.Select(c => c.WorkerProfileId).ToHashSet();

        string AvailabilityFor(Guid workerProfileId) => atWork.Contains(workerProfileId)
            ? "AtWork"
            : booked.Contains(workerProfileId)
                ? "Booked"
                : "Active";

        // Whether, not when. A row carrying one date could only ever show the first of however
        // many jobs a worker holds; GetWorkerBusyDatesQuery reports the lot, and that is what
        // the card opens.
        return workers.Select(w => w.ToDto(AvailabilityFor(w.WorkerProfileId))).ToList();
    }
}
