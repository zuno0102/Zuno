using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetOrderStages;

/// <summary>Every order stage's name, colour and order, in the order the filters show them.</summary>
public class GetOrderStagesQueryHandler(IApplicationDbContext dbContext)
    : IRequestHandler<GetOrderStagesQuery, List<OrderStageDto>>
{
    public async Task<List<OrderStageDto>> Handle(GetOrderStagesQuery request, CancellationToken cancellationToken) =>
        await dbContext.OrderStages
            .AsNoTracking()
            .OrderBy(s => s.SortOrder)
            .Select(s => new OrderStageDto
            {
                Code = s.Stage.ToString(),
                Label = s.DisplayName,
                SortOrder = s.SortOrder,
                Tone = s.Tone,
                ShowOnBookings = s.ShowOnBookings,
                ShowOnWork = s.ShowOnWork,
            })
            .ToListAsync(cancellationToken);
}
