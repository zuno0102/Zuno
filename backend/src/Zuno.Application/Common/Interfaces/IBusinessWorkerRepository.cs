using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Interfaces;

public interface IBusinessWorkerRepository
{
    Task<BusinessWorker?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    Task<BusinessWorker?> GetByBusinessAndWorkerAsync(
        Guid businessOwnerProfileId, Guid workerProfileId, CancellationToken cancellationToken);

    Task<List<BusinessWorker>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken);

    Task<List<BusinessWorker>> GetByWorkerIdAsync(
        Guid workerProfileId, BusinessWorkerStatus? status, CancellationToken cancellationToken);

    void Add(BusinessWorker businessWorker);
}
