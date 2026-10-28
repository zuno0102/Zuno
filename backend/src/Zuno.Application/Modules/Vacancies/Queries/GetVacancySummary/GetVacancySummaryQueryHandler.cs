using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancySummary;

public class GetVacancySummaryQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<GetVacancySummaryQuery, VacancySummaryDto>
{
    public async Task<VacancySummaryDto> Handle(GetVacancySummaryQuery request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var activePosts = await dbContext.Vacancies
            .Where(v => v.BusinessOwnerProfileId == businessProfileId)
            .Where(Vacancy.LiveAt(dateTimeProvider.UtcNow))
            .CountAsync(cancellationToken);

        // One grouped count for every list, rather than a query per tile.
        var byStatus = await dbContext.VacancyApplications
            .Where(a => a.Vacancy.BusinessOwnerProfileId == businessProfileId)
            .GroupBy(a => a.ApplicationStatus)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Status, x => x.Count, cancellationToken);

        return new VacancySummaryDto
        {
            ActivePosts = activePosts,
            NewCount = byStatus.GetValueOrDefault(VacancyApplicationStatus.Applied),
            WaitingCount = byStatus.GetValueOrDefault(VacancyApplicationStatus.Viewed),
            ShortlistedCount = byStatus.GetValueOrDefault(VacancyApplicationStatus.Shortlisted),
            HiredCount = byStatus.GetValueOrDefault(VacancyApplicationStatus.Hired),
        };
    }
}
