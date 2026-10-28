using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;

namespace Zuno.Application.Modules.Vacancies.Commands.UpdateVacancy;

public class UpdateVacancyCommandValidator(
    IApplicationDbContext dbContext, IOptions<VacancySettings> settings, IPlatformSettings platformSettings)
    : VacancyFieldsValidator<UpdateVacancyCommand>(dbContext, settings, platformSettings);
