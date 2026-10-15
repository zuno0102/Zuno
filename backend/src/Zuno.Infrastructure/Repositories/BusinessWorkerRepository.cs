using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class BusinessWorkerRepository(ZunoDbContext dbContext) : IBusinessWorkerRepository
{
    public Task<BusinessWorker?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.BusinessWorkers
            .Include(w => w.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(w => w.BusinessOwnerProfile).ThenInclude(bp => bp.User)
            .FirstOrDefaultAsync(w => w.Id == id, cancellationToken);

    public Task<BusinessWorker?> GetByBusinessAndWorkerAsync(
        Guid businessOwnerProfileId, Guid workerProfileId, CancellationToken cancellationToken) =>
        dbContext.BusinessWorkers
            .FirstOrDefaultAsync(
                w => w.BusinessOwnerProfileId == businessOwnerProfileId && w.WorkerProfileId == workerProfileId,
                cancellationToken);

    public async Task<List<BusinessWorker>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken) =>
        await dbContext.BusinessWorkers
            .Include(w => w.WorkerProfile).ThenInclude(wp => wp.User)
            .Where(w => w.BusinessOwnerProfileId == businessOwnerProfileId)
            .OrderByDescending(w => w.InvitedAt)
            .ToListAsync(cancellationToken);

    public async Task<List<BusinessWorker>> GetByWorkerIdAsync(
        Guid workerProfileId, BusinessWorkerStatus? status, CancellationToken cancellationToken)
    {
        var query = dbContext.BusinessWorkers
            .Include(w => w.BusinessOwnerProfile).ThenInclude(bp => bp.User)
            .Where(w => w.WorkerProfileId == workerProfileId);

        if (status.HasValue)
        {
            query = query.Where(w => w.AssignmentStatus == status.Value);
        }

        return await query.OrderByDescending(w => w.InvitedAt).ToListAsync(cancellationToken);
    }

    public void Add(BusinessWorker businessWorker) => dbContext.BusinessWorkers.Add(businessWorker);
}
