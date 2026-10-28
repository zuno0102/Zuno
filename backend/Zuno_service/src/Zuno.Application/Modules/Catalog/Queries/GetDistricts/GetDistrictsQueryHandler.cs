using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetDistricts;

public class GetDistrictsQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetDistrictsQuery, List<DistrictDto>>
{
    public async Task<List<DistrictDto>> Handle(GetDistrictsQuery request, CancellationToken cancellationToken)
    {
        var query = dbContext.Districts.Include(d => d.State).AsQueryable();

        if (request.StateIds is { Count: > 0 })
        {
            query = query.Where(d => request.StateIds.Contains(d.StateId));
        }

        var districts = await query
            .OrderBy(d => d.State.Name)
            .ThenBy(d => d.Name)
            .ToListAsync(cancellationToken);

        return districts.Select(d => d.ToDto()).ToList();
    }
}
