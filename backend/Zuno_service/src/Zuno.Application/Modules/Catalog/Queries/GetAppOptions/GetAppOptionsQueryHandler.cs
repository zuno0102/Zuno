using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Application.Modules.Vacancies.Common;

namespace Zuno.Application.Modules.Catalog.Queries.GetAppOptions;

/// <summary>
/// Reads the same settings the server validates against, so a form in the app can never allow what
/// the server would refuse, or refuse what it would allow.
/// </summary>
public class GetAppOptionsQueryHandler(
    IPlatformSettings platformSettings,
    IOptions<FileStorageSettings> fileStorage,
    IOptions<VacancySettings> vacancies) : IRequestHandler<GetAppOptionsQuery, AppOptionsDto>
{
    public Task<AppOptionsDto> Handle(GetAppOptionsQuery request, CancellationToken cancellationToken)
    {
        var rules = platformSettings.Current;

        return Task.FromResult(new AppOptionsDto
        {
            HiringPostMinDurationMinutes = rules.HiringPostMinDurationMinutes,
            HiringPostMaxDurationMinutes = rules.HiringPostMaxDurationMinutes,
            HiringPostDefaultDurationMinutes = rules.HiringPostDefaultDurationMinutes,
            HiringPostMaxWorkers = rules.HiringPostMaxWorkers,
            OrderMaxCrewSize = rules.OrderMaxCrewSize,
            ServiceMaxQuestions = rules.ServiceMaxQuestions,
            ServiceImageSlots = rules.ServiceImageSlots,
            ServiceVideoMaxSeconds = rules.ServiceVideoMaxSeconds,
            ServiceVideoMaxBytes = fileStorage.Value.MaxVideoFileSizeBytes,
            ImageMaxBytes = fileStorage.Value.MaxFileSizeBytes,
            ImageUploadQuality = rules.ImageUploadQuality,
            ImageUploadMaxWidth = rules.ImageUploadMaxWidth,
            MaxDaysAhead = rules.BookingMaxDaysAhead,
            CustomerBookingMaxDaysAhead = rules.CustomerBookingMaxDaysAhead,
            VacancyMaxOpenings = rules.VacancyMaxOpenings,
            VacancyMaxContractMonths = rules.VacancyMaxContractMonths,
            VacancyMaxFields = vacancies.Value.MaxRequirements,
            VacancyTitleMaxLength = VacancyFieldLimits.MaxTitleLength,
            VacancyDescriptionMaxLength = VacancyFieldLimits.MaxDescriptionLength,
            VacancyLocationMaxLength = VacancyFieldLimits.MaxLocationLength,
            VacancyFieldNameMaxLength = VacancyFieldLimits.MaxPromptLength,
        });
    }
}
