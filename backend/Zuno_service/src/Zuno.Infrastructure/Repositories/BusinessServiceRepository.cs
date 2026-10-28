using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class BusinessServiceRepository(ZunoDbContext dbContext) : IBusinessServiceRepository
{
    public Task<BusinessService?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.BusinessServices
            .Include(s => s.ServiceCategory)
            .Include(s => s.ServiceSubCategory)
            .Include(s => s.Media)
            .Include(s => s.TargetDistricts).ThenInclude(t => t.District).ThenInclude(d => d.State)
            .Include(s => s.Variants).ThenInclude(v => v.Media)
            .Include(s => s.Variants).ThenInclude(v => v.ServiceSubCategory)
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == id, cancellationToken);

    public async Task<List<BusinessService>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken) =>
        await dbContext.BusinessServices
            .Include(s => s.ServiceCategory)
            .Include(s => s.ServiceSubCategory)
            .Include(s => s.Media)
            .Include(s => s.TargetDistricts).ThenInclude(t => t.District).ThenInclude(d => d.State)
            .Include(s => s.Variants).ThenInclude(v => v.Media)
            .Include(s => s.Variants).ThenInclude(v => v.ServiceSubCategory)
            .Include(s => s.Questions)
            .Where(s => s.BusinessOwnerProfileId == businessOwnerProfileId)
            .OrderBy(s => s.Name)
            .ToListAsync(cancellationToken);

    public void Add(BusinessService service) => dbContext.BusinessServices.Add(service);

    public void Remove(BusinessService service) => dbContext.BusinessServices.Remove(service);
}
