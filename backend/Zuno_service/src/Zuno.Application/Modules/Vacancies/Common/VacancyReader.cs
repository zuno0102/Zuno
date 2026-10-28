using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>Reads one vacancy back in its DTO shape — what every write returns once it has saved.</summary>
public static class VacancyReader
{
    public static Task<VacancyDto> GetAsync(
        IApplicationDbContext dbContext,
        Guid vacancyId,
        Guid? workerProfileId,
        DateTimeOffset now,
        CancellationToken cancellationToken) =>
        dbContext.Vacancies
            .AsNoTracking()
            .Where(v => v.Id == vacancyId)
            .Select(VacancyProjections.ToDto(workerProfileId, now))
            .FirstAsync(cancellationToken);
}
