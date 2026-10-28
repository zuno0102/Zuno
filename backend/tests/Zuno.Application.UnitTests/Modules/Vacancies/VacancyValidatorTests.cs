using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;
using Zuno.Application.Modules.Vacancies.Commands.CreateVacancy;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

public class VacancyValidatorTests
{
    private static readonly Guid FullTime = Guid.NewGuid();
    private static readonly Guid Retired = Guid.NewGuid();

    private static CreateVacancyCommandValidator Validator(int maxRequirements = 15, PlatformRules? rules = null)
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.VacancyJobTypes).Returns(TestDbSet.From(
            new VacancyJobType { Id = FullTime, Name = "Full-time", IsActive = true },
            new VacancyJobType { Id = Retired, Name = "Old", IsActive = false }));
        db.Setup(d => d.ServiceSubCategories).Returns(TestDbSet.From<ServiceSubCategory>());

        return new CreateVacancyCommandValidator(
            db.Object, Options.Create(new VacancySettings { MaxRequirements = maxRequirements }),
            new TestPlatformSettings(rules));
    }

    private static CreateVacancyCommand Valid() => new()
    {
        Title = "Shop helper",
        JobTypeId = FullTime,
        Openings = 1,
        SalaryMin = 12000,
        SalaryMax = 15000,
        WorkingDaysPerWeek = 6,
        Requirements =
        [
            new VacancyRequirementInput { Kind = VacancyRequirementKind.File, Prompt = "Aadhaar", IsRequired = true },
            new VacancyRequirementInput { Kind = VacancyRequirementKind.YesNo, Prompt = "Can you ride a bike?" },
        ],
    };

    private static async Task<IEnumerable<string>> Errors(CreateVacancyCommand command, int maxRequirements = 15) =>
        (await Validator(maxRequirements).ValidateAsync(command)).Errors.Select(e => e.PropertyName);

    [Fact]
    public async Task Validate_ValidForm_Passes() =>
        (await Errors(Valid())).Should().BeEmpty();

    [Theory]
    [InlineData(10, 10, true)]
    [InlineData(10, 11, false)]
    [InlineData(10, 0, false)]
    [InlineData(2000, 1500, true)]
    public async Task Validate_Openings_FollowTheConfiguredMaximum(int maximum, int asked, bool allowed)
    {
        var command = Valid();
        command.Openings = asked;

        var result = await Validator(rules: PlatformRules.Defaults with { VacancyMaxOpenings = maximum }).ValidateAsync(command);

        result.IsValid.Should().Be(allowed);
    }

    [Theory]
    [InlineData(12, 12, true)]
    [InlineData(12, 13, false)]
    [InlineData(12, 0, false)]
    public async Task Validate_ContractMonths_FollowTheConfiguredMaximum(int maximum, short asked, bool allowed)
    {
        var command = Valid();
        command.ContractMonths = asked;

        var result = await Validator(rules: PlatformRules.Defaults with { VacancyMaxContractMonths = maximum }).ValidateAsync(command);

        result.IsValid.Should().Be(allowed);
    }

    [Fact]
    public async Task Validate_RetiredJobType_IsRefused()
    {
        var command = Valid();
        command.JobTypeId = Retired;

        (await Errors(command)).Should().Contain(nameof(command.JobTypeId));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(100_000_000)]
    public async Task Validate_SalaryOutOfRange_IsRefused(decimal salary)
    {
        var command = Valid();
        command.SalaryMin = salary;
        command.SalaryMax = null;

        (await Errors(command)).Should().Contain(nameof(command.SalaryMin));
    }

    [Fact]
    public async Task Validate_RangeTopBelowBottom_IsRefused()
    {
        var command = Valid();
        command.SalaryMax = command.SalaryMin - 1;

        (await Errors(command)).Should().Contain(nameof(command.SalaryMax));
    }

    [Fact]
    public async Task Validate_RangeTopEqualToBottom_Passes()
    {
        var command = Valid();
        command.SalaryMax = command.SalaryMin;

        (await Errors(command)).Should().BeEmpty();
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(1, true)]
    [InlineData(7, true)]
    [InlineData(8, false)]
    public async Task Validate_WorkingDaysBoundaries(short days, bool valid)
    {
        var command = Valid();
        command.WorkingDaysPerWeek = days;

        (await Errors(command)).Contains(nameof(command.WorkingDaysPerWeek)).Should().Be(!valid);
    }

    [Fact]
    public async Task Validate_HalfAShift_IsRefused()
    {
        var command = Valid();
        command.ShiftStart = new TimeOnly(9, 0);

        (await Errors(command)).Should().NotBeEmpty();
    }

    [Fact]
    public async Task Validate_HalfACoordinate_IsRefused()
    {
        var command = Valid();
        command.Latitude = 8.18m;

        (await Errors(command)).Should().NotBeEmpty();
    }

    [Fact]
    public async Task Validate_FieldWithoutName_IsRefused()
    {
        var command = Valid();
        command.Requirements.Add(new VacancyRequirementInput { Kind = VacancyRequirementKind.Text, Prompt = " " });

        (await Errors(command)).Should().NotBeEmpty();
    }

    [Fact]
    public async Task Validate_SameFieldNameTwice_IsRefused()
    {
        var command = Valid();
        command.Requirements.Add(new VacancyRequirementInput { Kind = VacancyRequirementKind.Text, Prompt = " aadhaar " });

        (await Errors(command)).Should().Contain(nameof(command.Requirements));
    }

    [Fact]
    public async Task Validate_PromptLongerThanTheColumn_IsRefused()
    {
        var command = Valid();
        command.Requirements[1].Prompt = new string('x', VacancyFieldLimits.MaxPromptLength + 1);

        (await Errors(command)).Should().NotBeEmpty();
    }

    [Theory]
    [InlineData(2, true)]
    [InlineData(1, false)]
    public async Task Validate_RequirementLimit_ComesFromSettings(int maxRequirements, bool valid) =>
        (await Errors(Valid(), maxRequirements)).Any().Should().Be(!valid);

    [Fact]
    public async Task Validate_InjectionInTitle_IsJustText()
    {
        var command = Valid();
        command.Title = "'; DROP TABLE vacancies; --";

        (await Errors(command)).Should().BeEmpty("it is stored as a parameter, never run");
    }

    // ---- Applying ------------------------------------------------------------------------------------

    private static ApplyToVacancyCommandValidator ApplyValidator() =>
        new(Options.Create(new VacancySettings { MaxRequirements = 15, MaxApplicationUploadBytes = 1000 }));

    [Fact]
    public async Task ValidateApply_FilesOverTheTotal_IsRefused()
    {
        var command = new ApplyToVacancyCommand
        {
            Answers = [new(Guid.NewGuid(), null, Stream.Null, 600), new(Guid.NewGuid(), null, Stream.Null, 401)],
        };

        (await ApplyValidator().ValidateAsync(command)).IsValid.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateApply_FilesExactlyAtTheTotal_Passes()
    {
        var command = new ApplyToVacancyCommand
        {
            Answers = [new(Guid.NewGuid(), null, Stream.Null, 600), new(Guid.NewGuid(), null, Stream.Null, 400)],
        };

        (await ApplyValidator().ValidateAsync(command)).IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task ValidateApply_SameRequirementTwice_IsRefused()
    {
        var id = Guid.NewGuid();
        var command = new ApplyToVacancyCommand { Answers = [new(id, "a", null, 0), new(id, "b", null, 0)] };

        (await ApplyValidator().ValidateAsync(command)).IsValid.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateApply_AnswerTooLong_IsRefused()
    {
        var command = new ApplyToVacancyCommand
        {
            Answers = [new(Guid.NewGuid(), new string('x', ApplyToVacancyCommandValidator.MaxAnswerLength + 1), null, 0)],
        };

        (await ApplyValidator().ValidateAsync(command)).IsValid.Should().BeFalse();
    }
}
