using FluentAssertions;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Catalog.Queries.GetAppOptions;
using Zuno.Application.Modules.Vacancies.Common;

namespace Zuno.Application.UnitTests.Modules.Catalog;

/// <summary>The app's form limits are the server's own settings, never a second copy.</summary>
public class GetAppOptionsQueryHandlerTests
{
    private static Task<Application.Modules.Catalog.DTOs.AppOptionsDto> Options(PlatformRules rules) =>
        new GetAppOptionsQueryHandler(
                new TestPlatformSettings(rules),
                Microsoft.Extensions.Options.Options.Create(new FileStorageSettings { MaxVideoFileSizeBytes = 7_000 }),
                Microsoft.Extensions.Options.Options.Create(new VacancySettings { MaxRequirements = 4 }))
            .Handle(new GetAppOptionsQuery(), CancellationToken.None);

    [Fact]
    public async Task Limits_FollowThePlatformSettings()
    {
        var result = await Options(PlatformRules.Defaults with
        {
            HiringPostMinDurationMinutes = 30,
            HiringPostMaxDurationMinutes = 600,
            HiringPostMaxWorkers = 7,
            VacancyMaxOpenings = 42,
            VacancyMaxContractMonths = 18,
            BookingMaxDaysAhead = 90,
            ServiceVideoMaxSeconds = 45,
            ImageUploadQuality = 70,
        });

        result.HiringPostMinDurationMinutes.Should().Be(30);
        result.HiringPostMaxDurationMinutes.Should().Be(600);
        result.HiringPostMaxWorkers.Should().Be(7);
        result.VacancyMaxOpenings.Should().Be(42);
        result.VacancyMaxContractMonths.Should().Be(18);
        result.MaxDaysAhead.Should().Be(90);
        result.ServiceVideoMaxSeconds.Should().Be(45);
        result.ImageUploadQuality.Should().Be(70);
    }

    [Fact]
    public async Task UploadAndFieldLimits_FollowTheirSettings()
    {
        var result = await Options(PlatformRules.Defaults);

        result.ServiceVideoMaxBytes.Should().Be(7_000);
        result.VacancyMaxFields.Should().Be(4);
        result.VacancyTitleMaxLength.Should().Be(VacancyFieldLimits.MaxTitleLength);
        result.VacancyFieldNameMaxLength.Should().Be(VacancyFieldLimits.MaxPromptLength);
    }
}
