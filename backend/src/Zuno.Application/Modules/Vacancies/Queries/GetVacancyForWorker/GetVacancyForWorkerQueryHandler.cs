using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyForWorker;

public class GetVacancyForWorkerQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<GetVacancyForWorkerQuery, VacancyDto>
{
    public async Task<VacancyDto> Handle(GetVacancyForWorkerQuery request, CancellationToken cancellationToken)
    {
        var workerProfileId = await VacancyActor.WorkerProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var now = dateTimeProvider.UtcNow;

        // An unpaid or stopped vacancy is not public. The worker's own application is the one way in,
        // so they can still see what they applied for after hiring closes.
        return await dbContext.Vacancies
            .AsNoTracking()
            .Where(v => v.Id == request.VacancyId)
            .Where(v => (v.VacancyStatus == VacancyStatus.Open && v.ExpiresAt > now)
                || v.Applications.Any(a => a.WorkerProfileId == workerProfileId))
            .Select(VacancyProjections.ToDto(workerProfileId, now))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Vacancy), request.VacancyId);
    }
}
