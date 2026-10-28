using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Worker.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Worker.Queries.GetMyWorkerProfile;

public class GetMyWorkerProfileQueryHandler(
    ICurrentUserService currentUserService,
    IWorkerEarningsService earningsService,
    IApplicationDbContext dbContext,
    IPlatformSettings platformSettings) : IRequestHandler<GetMyWorkerProfileQuery, WorkerProfileDto>
{
    public async Task<WorkerProfileDto> Handle(
        GetMyWorkerProfileQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await dbContext.WorkerProfiles
            .Include(w => w.User)
            .Include(w => w.PayoutDetail)
            .FirstOrDefaultAsync(w => w.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        // Through the shared service, not worked out here. This used to read hiring-post
        // applications alone, so a worker put on an order by hand read as having earned nothing and
        // done no jobs — and the dashboard would have repeated the mistake in a second place.
        var earnings = await earningsService.GetAsync(profile.Id, cancellationToken);

        return profile.ToDto(earnings, platformSettings.Current.WorkerLevels);
    }
}
