using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyApplications;

public class GetVacancyApplicationsQueryHandler(
    ICurrentUserService currentUserService,
    IOptions<VacancySettings> settings,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetVacancyApplicationsQuery, VacancyPageDto<VacancyApplicationDto>>
{
    public async Task<VacancyPageDto<VacancyApplicationDto>> Handle(
        GetVacancyApplicationsQuery request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        // Ownership is part of the filter either way: another business's applicants are never in it.
        var query = dbContext.VacancyApplications
            .AsNoTracking()
            .Where(a => a.Vacancy.BusinessOwnerProfileId == businessProfileId);

        if (request.VacancyId is { } vacancyId)
        {
            // A vacancy that is not theirs is reported as missing, not as an empty list.
            var owns = await dbContext.Vacancies.AnyAsync(
                v => v.Id == vacancyId && v.BusinessOwnerProfileId == businessProfileId, cancellationToken);

            if (!owns)
            {
                throw new EntityNotFoundException(nameof(Vacancy), vacancyId);
            }

            query = query.Where(a => a.VacancyId == vacancyId);
        }

        var take = settings.Value.PageSize(request.Take);

        // A rejected applicant is gone from the business's side; only the worker still sees the answer.
        query = request.Status is { } status
            ? query.Where(a => a.ApplicationStatus == status)
            : query.Where(a => a.ApplicationStatus != VacancyApplicationStatus.Rejected);

        if (request.Before is { } before)
        {
            query = query.Where(a => a.CreatedDate < before);
        }

        var items = await query
            .OrderByDescending(a => a.CreatedDate)
            .Take(take)
            .Select(VacancyProjections.ToApplicationDto)
            .ToListAsync(cancellationToken);

        return new VacancyPageDto<VacancyApplicationDto>
        {
            Items = items,
            NextBefore = items.Count == take ? items[^1].AppliedAt : null,
        };
    }
}
