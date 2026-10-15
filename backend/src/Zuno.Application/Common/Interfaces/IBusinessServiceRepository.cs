using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IBusinessServiceRepository
{
    Task<BusinessService?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    Task<List<BusinessService>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken);

    void Add(BusinessService service);

    void Remove(BusinessService service);
}
