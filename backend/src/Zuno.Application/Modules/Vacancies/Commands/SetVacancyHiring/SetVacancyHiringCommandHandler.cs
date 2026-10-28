using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.SetVacancyHiring;

public class SetVacancyHiringCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<SetVacancyHiringCommand, VacancyDto>
{
    public async Task<VacancyDto> Handle(SetVacancyHiringCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var vacancy = await VacancyActor.OwnedVacancyAsync(
            dbContext.Vacancies, request.VacancyId, businessProfileId, cancellationToken);

        var now = dateTimeProvider.UtcNow;

        if (request.IsHiring)
        {
            vacancy.ResumeHiring(now);
        }
        else
        {
            vacancy.StopHiring(now);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return await VacancyReader.GetAsync(dbContext, vacancy.Id, null, now, cancellationToken);
    }
}
