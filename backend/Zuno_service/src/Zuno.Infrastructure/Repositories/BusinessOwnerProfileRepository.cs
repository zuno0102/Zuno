using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class BusinessOwnerProfileRepository(ZunoDbContext dbContext) : IBusinessOwnerProfileRepository
{
    public Task<BusinessOwnerProfile?> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.BusinessOwnerProfiles
            .Include(bp => bp.BusinessAddress)
            .FirstOrDefaultAsync(bp => bp.UserId == userId, cancellationToken);

    public Task<BusinessOwnerProfile?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.BusinessOwnerProfiles
            .Include(bp => bp.BusinessAddress)
            .FirstOrDefaultAsync(bp => bp.Id == id, cancellationToken);
}
