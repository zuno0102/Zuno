using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetMyVacancies;

public class GetMyVacanciesQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IOptions<VacancySettings> settings,
    IApplicationDbContext dbContext) : IRequestHandler<GetMyVacanciesQuery, VacancyPageDto<VacancyDto>>
{
    public async Task<VacancyPageDto<VacancyDto>> Handle(GetMyVacanciesQuery request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var take = settings.Value.PageSize(request.Take);

        var query = dbContext.Vacancies
            .AsNoTracking()
            .Where(v => v.BusinessOwnerProfileId == businessProfileId);

        if (request.Before is { } before)
        {
            query = query.Where(v => v.CreatedDate < before);
        }

        var items = await query
            .OrderByDescending(v => v.CreatedDate)
            .Take(take)
            .Select(VacancyProjections.ToDto(null, dateTimeProvider.UtcNow))
            .ToListAsync(cancellationToken);

        return new VacancyPageDto<VacancyDto>
        {
            Items = items,
            NextBefore = items.Count == take ? items[^1].CreatedDate : null,
        };
    }
}
