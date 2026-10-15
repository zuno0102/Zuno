using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetStates;

public class GetStatesQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetStatesQuery, List<StateDto>>
{
    public async Task<List<StateDto>> Handle(GetStatesQuery request, CancellationToken cancellationToken)
    {
        var states = await dbContext.States
            .OrderBy(s => s.Name)
            .ToListAsync(cancellationToken);

        return states.Select(s => s.ToDto()).ToList();
    }
}
