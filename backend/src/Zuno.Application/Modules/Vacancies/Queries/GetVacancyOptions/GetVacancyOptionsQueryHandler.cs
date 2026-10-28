using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyOptions;

public class GetVacancyOptionsQueryHandler(IApplicationDbContext dbContext, IOptions<VacancySettings> settings)
    : IRequestHandler<GetVacancyOptionsQuery, VacancyOptionsDto>
{
    public async Task<VacancyOptionsDto> Handle(GetVacancyOptionsQuery request, CancellationToken cancellationToken) => new()
    {
        JobTypes = await dbContext.VacancyJobTypes
            .AsNoTracking()
            .Where(t => t.IsActive)
            .OrderBy(t => t.SortOrder)
            .Select(t => new VacancyJobTypeDto { Id = t.Id, Name = t.Name, HasFixedLength = t.HasFixedLength })
            .ToListAsync(cancellationToken),
        FeePlans = await dbContext.VacancyFeePlans
            .AsNoTracking()
            .Where(p => p.IsActive)
            .OrderBy(p => p.SortOrder)
            .Select(p => new VacancyFeePlanDto { Id = p.Id, Name = p.Name, Amount = p.Amount, ListingDays = p.ListingDays })
            .ToListAsync(cancellationToken),
        AllowedFileExtensions = [.. settings.Value.AllowedFileExtensions],
        MaxFileSizeBytes = settings.Value.MaxFileSizeBytes,
    };
}
