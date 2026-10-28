using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IBusinessOwnerProfileRepository
{
    Task<BusinessOwnerProfile?> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken);

    Task<BusinessOwnerProfile?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}
