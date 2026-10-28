using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Commands.MarkVacancyApplicationViewed;

public class MarkVacancyApplicationViewedCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<MarkVacancyApplicationViewedCommand, VacancyApplicationDto>
{
    public async Task<VacancyApplicationDto> Handle(
        MarkVacancyApplicationViewedCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var application = await dbContext.VacancyApplications
            .FirstOrDefaultAsync(
                a => a.Id == request.ApplicationId && a.Vacancy.BusinessOwnerProfileId == businessProfileId,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(VacancyApplication), request.ApplicationId);

        // No notification: being looked at is shown on the worker's status, not pushed at them.
        if (application.MarkViewed(dateTimeProvider.UtcNow))
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return await dbContext.VacancyApplications
            .AsNoTracking()
            .Where(a => a.Id == application.Id)
            .Select(VacancyProjections.ToApplicationDto)
            .FirstAsync(cancellationToken);
    }
}
