using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;

namespace Zuno.Application.Modules.Vacancies.Commands.CreateVacancy;

public class CreateVacancyCommandValidator(
    IApplicationDbContext dbContext, IOptions<VacancySettings> settings, IPlatformSettings platformSettings)
    : VacancyFieldsValidator<CreateVacancyCommand>(dbContext, settings, platformSettings);
