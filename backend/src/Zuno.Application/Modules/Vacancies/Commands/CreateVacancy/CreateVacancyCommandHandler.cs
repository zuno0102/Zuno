using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Commands.CreateVacancy;

public class CreateVacancyCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPlatformSettings platformSettings,
    IApplicationDbContext dbContext) : IRequestHandler<CreateVacancyCommand, VacancyDto>
{
    public async Task<VacancyDto> Handle(CreateVacancyCommand request, CancellationToken cancellationToken)
    {
        var businessProfileId = await VacancyActor.BusinessProfileIdAsync(currentUserService, dbContext, cancellationToken);

        var vacancy = new Vacancy
        {
            BusinessOwnerProfileId = businessProfileId,
            VacancyStatus = VacancyStatus.AwaitingPayment,
        };

        await VacancyWriter.ApplyAsync(vacancy, request, platformSettings.Current, dbContext, cancellationToken);

        dbContext.Vacancies.Add(vacancy);
        await dbContext.SaveChangesAsync(cancellationToken);

        return await VacancyReader.GetAsync(dbContext, vacancy.Id, null, dateTimeProvider.UtcNow, cancellationToken);
    }
}
