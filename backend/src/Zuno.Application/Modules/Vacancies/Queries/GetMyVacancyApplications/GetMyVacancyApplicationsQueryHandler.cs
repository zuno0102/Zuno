using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetMyVacancyApplications;

public class GetMyVacancyApplicationsQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IOptions<VacancySettings> settings,
    IApplicationDbContext dbContext) : IRequestHandler<GetMyVacancyApplicationsQuery, VacancyPageDto<VacancyDto>>
{
    public async Task<VacancyPageDto<VacancyDto>> Handle(
        GetMyVacancyApplicationsQuery request, CancellationToken cancellationToken)
    {
        var workerProfileId = await VacancyActor.WorkerProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var take = settings.Value.PageSize(request.Take);

        var applications = dbContext.VacancyApplications
            .AsNoTracking()
            .Where(a => a.WorkerProfileId == workerProfileId);

        if (request.Before is { } before)
        {
            applications = applications.Where(a => a.CreatedDate < before);
        }

        var items = await applications
            .OrderByDescending(a => a.CreatedDate)
            .Take(take)
            .Select(a => a.Vacancy)
            .Select(VacancyProjections.ToDto(workerProfileId, dateTimeProvider.UtcNow))
            .ToListAsync(cancellationToken);

        return new VacancyPageDto<VacancyDto>
        {
            Items = items,
            NextBefore = items.Count == take ? items[^1].MyAppliedAt : null,
        };
    }
}
