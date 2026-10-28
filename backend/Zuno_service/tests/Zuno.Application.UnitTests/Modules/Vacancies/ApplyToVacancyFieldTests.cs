using System.Text;
using FluentAssertions;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

/// <summary>
/// Each custom field is checked as the kind of field it is, and nothing is kept from an application
/// that is refused — least of all an uploaded file.
/// </summary>
public class ApplyToVacancyFieldTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);
    private static readonly Guid UserId = Guid.NewGuid();

    private readonly WorkerProfile _worker = new() { Id = Guid.NewGuid(), UserId = UserId };
    private readonly Mock<IPrivateDocumentStore> _store = new();
    private readonly Mock<IApplicationDbContext> _db = new();
    private readonly List<VacancyApplication> _saved = [];

    private Vacancy LiveVacancy(params VacancyRequirement[] fields)
    {
        var vacancy = new Vacancy
        {
            Id = Guid.NewGuid(),
            Title = "Shop helper",
            VacancyStatus = VacancyStatus.Open,
            ExpiresAt = Now.AddDays(10),
            BusinessOwnerProfile = new BusinessOwnerProfile { UserId = Guid.NewGuid(), BusinessName = "Nila" },
            VacancyJobType = new VacancyJobType { Name = "Full-time" },
        };
        foreach (var field in fields)
        {
            vacancy.Requirements.Add(field);
        }

        var applications = new Mock<Microsoft.EntityFrameworkCore.DbSet<VacancyApplication>>();
        var empty = TestDbSet.From<VacancyApplication>();
        applications.As<IQueryable<VacancyApplication>>().Setup(q => q.Provider).Returns(((IQueryable<VacancyApplication>)empty).Provider);
        applications.As<IQueryable<VacancyApplication>>().Setup(q => q.Expression).Returns(((IQueryable<VacancyApplication>)empty).Expression);
        applications.As<IQueryable<VacancyApplication>>().Setup(q => q.ElementType).Returns(((IQueryable<VacancyApplication>)empty).ElementType);
        applications.Setup(s => s.Add(It.IsAny<VacancyApplication>())).Callback<VacancyApplication>(_saved.Add);

        _db.Setup(d => d.Vacancies).Returns(TestDbSet.From(vacancy));
        _db.Setup(d => d.WorkerProfiles).Returns(TestDbSet.From(_worker));
        _db.Setup(d => d.VacancyApplications).Returns(applications.Object);
        _store.Setup(s => s.SaveAsync(It.IsAny<string>(), It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((string folder, Stream _, string ext, CancellationToken _) => $"{folder}/file.{ext}");
        return vacancy;
    }

    private static VacancyRequirement Field(VacancyRequirementKind kind, string prompt, bool required = true) =>
        new() { Id = Guid.NewGuid(), Kind = kind, Prompt = prompt, IsRequired = required };

    private Task Apply(Vacancy vacancy, params VacancyAnswerUpload[] answers)
    {
        var currentUser = new Mock<ICurrentUserService>();
        currentUser.Setup(c => c.UserId).Returns(UserId);
        var clock = new Mock<IDateTimeProvider>();
        clock.Setup(c => c.UtcNow).Returns(Now);

        var handler = new ApplyToVacancyCommandHandler(
            currentUser.Object,
            clock.Object,
            _store.Object,
            Mock.Of<INotificationSender>(),
            Options.Create(new VacancySettings
            {
                AllowedFileExtensions = ["pdf", "jpg", "jpeg", "png"],
                MaxFileSizeBytes = 1024,
            }),
            _db.Object);

        return handler.Handle(new ApplyToVacancyCommand { VacancyId = vacancy.Id, Answers = [.. answers] }, CancellationToken.None);
    }

    /// <summary>Runs the apply; the read-back afterwards is not under test here and may throw.</summary>
    private async Task ApplyIgnoringReadBack(Vacancy vacancy, params VacancyAnswerUpload[] answers)
    {
        try
        {
            await Apply(vacancy, answers);
        }
        catch (InvalidOperationException)
        {
            // The DTO read-back runs against a mock with no saved rows.
        }
    }

    private static VacancyAnswerUpload Text(VacancyRequirement field, string text) => new(field.Id, text, null, 0);

    private static VacancyAnswerUpload File(VacancyRequirement field, string content)
    {
        var bytes = Encoding.Latin1.GetBytes(content);
        return new VacancyAnswerUpload(field.Id, null, new MemoryStream(bytes), bytes.Length);
    }

    [Theory]
    [InlineData("3", "3")]
    [InlineData("2.5", "2.5")]
    [InlineData(" 10 ", "10")]
    public async Task Number_IsStoredAsANumber(string typed, string stored)
    {
        var years = Field(VacancyRequirementKind.Number, "Years of experience");

        await ApplyIgnoringReadBack(LiveVacancy(years), Text(years, typed));

        _saved.Single().Answers.Single().AnswerText.Should().Be(stored);
    }

    [Theory]
    [InlineData("three")]
    [InlineData("1,00,000x")]
    public async Task Number_ThatIsNotANumber_IsRefused(string typed)
    {
        var years = Field(VacancyRequirementKind.Number, "Years of experience");

        var act = () => Apply(LiveVacancy(years), Text(years, typed));

        await act.Should().ThrowAsync<DomainException>().WithMessage("*must be a number*");
        _saved.Should().BeEmpty();
    }

    [Theory]
    [InlineData("yes", "Yes")]
    [InlineData("NO", "No")]
    public async Task YesNo_IsNormalised(string typed, string stored)
    {
        var bike = Field(VacancyRequirementKind.YesNo, "Do you have a bike?");

        await ApplyIgnoringReadBack(LiveVacancy(bike), Text(bike, typed));

        _saved.Single().Answers.Single().AnswerText.Should().Be(stored);
    }

    [Fact]
    public async Task YesNo_AnythingElse_IsRefused()
    {
        var bike = Field(VacancyRequirementKind.YesNo, "Do you have a bike?");

        var act = () => Apply(LiveVacancy(bike), Text(bike, "maybe"));

        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task RequiredText_Missing_IsRefused()
    {
        var area = Field(VacancyRequirementKind.Text, "Your area");

        var act = () => Apply(LiveVacancy(area));

        await act.Should().ThrowAsync<DomainException>().WithMessage("*Your area*");
    }

    [Fact]
    public async Task OptionalField_Missing_IsSkipped()
    {
        var area = Field(VacancyRequirementKind.Text, "Your area", required: false);

        await ApplyIgnoringReadBack(LiveVacancy(area));

        _saved.Single().Answers.Should().BeEmpty();
    }

    [Fact]
    public async Task File_IsSavedPrivately_AndNamedAfterTheField()
    {
        var aadhaar = Field(VacancyRequirementKind.File, "Aadhaar / ID");

        await ApplyIgnoringReadBack(LiveVacancy(aadhaar), File(aadhaar, "%PDF-1.4 card"));

        var answer = _saved.Single().Answers.Single();
        answer.FileName.Should().Be("Aadhaar  ID.pdf", "only plain characters reach the download name");
        answer.ContentType.Should().Be("application/pdf");
        answer.FileKey.Should().StartWith("vacancies/");
    }

    [Fact]
    public async Task File_ThatIsAScript_IsRefusedAndNothingIsKept()
    {
        var aadhaar = Field(VacancyRequirementKind.File, "Aadhaar");

        var act = () => Apply(LiveVacancy(aadhaar), File(aadhaar, "#!/bin/sh\necho pwned"));

        await act.Should().ThrowAsync<DomainException>().WithMessage("*file types*");
        _store.Verify(s => s.SaveAsync(It.IsAny<string>(), It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
        _store.Verify(s => s.DeleteFolder(It.IsAny<string>()), Times.Once);
    }

    [Fact]
    public async Task File_OverTheConfiguredSize_IsRefused()
    {
        var resume = Field(VacancyRequirementKind.File, "Resume");

        var act = () => Apply(LiveVacancy(resume), File(resume, "%PDF-" + new string('x', 2000)));

        await act.Should().ThrowAsync<DomainException>().WithMessage("*0MB or smaller*");
    }

    [Fact]
    public async Task Answer_ForAFieldTheFormNoLongerHas_IsRefused()
    {
        var area = Field(VacancyRequirementKind.Text, "Your area");

        var act = () => Apply(LiveVacancy(area), Text(area, "Nagercoil"), new VacancyAnswerUpload(Guid.NewGuid(), "x", null, 0));

        await act.Should().ThrowAsync<DomainException>().WithMessage("*form has changed*");
    }
}
