using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.UpdateVacancy;

public class UpdateVacancyCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPlatformSettings platformSettings,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateVacancyCommand, VacancyDto>
{
    public async Task<VacancyDto> Handle(UpdateVacancyCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var vacancy = await VacancyActor.OwnedVacancyAsync(
            dbContext.Vacancies.Include(v => v.Requirements),
            request.VacancyId,
            businessProfileId,
            cancellationToken);

        await VacancyWriter.ApplyAsync(vacancy, request, platformSettings.Current, dbContext, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return await VacancyReader.GetAsync(dbContext, vacancy.Id, null, dateTimeProvider.UtcNow, cancellationToken);
    }
}
