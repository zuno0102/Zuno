using FluentAssertions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

/// <summary>
/// An application goes New → Waiting by being opened, then the business decides: shortlist, hire or
/// reject. Rejecting is final and deletes what the worker sent.
/// </summary>
public class VacancyApplicationStatusTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);

    private static VacancyApplication Application(VacancyApplicationStatus status = VacancyApplicationStatus.Applied)
    {
        var application = new VacancyApplication { ApplicationStatus = status, BusinessNote = "Call Monday" };
        application.Answers.Add(new VacancyApplicationAnswer { AnswerText = "Yes" });
        application.Answers.Add(new VacancyApplicationAnswer { FileKey = "vacancies/v/a/x.pdf", FileName = "Aadhaar.pdf" });
        return application;
    }

    [Fact]
    public void MarkViewed_WhenNew_MovesToWaiting()
    {
        var application = Application();

        application.MarkViewed(Now).Should().BeTrue();

        application.ApplicationStatus.Should().Be(VacancyApplicationStatus.Viewed);
        application.StatusChangedAt.Should().Be(Now);
    }

    [Theory]
    [InlineData(VacancyApplicationStatus.Viewed)]
    [InlineData(VacancyApplicationStatus.Shortlisted)]
    [InlineData(VacancyApplicationStatus.Hired)]
    [InlineData(VacancyApplicationStatus.Rejected)]
    public void MarkViewed_WhenAlreadyPastNew_ChangesNothing(VacancyApplicationStatus status)
    {
        var application = Application(status);

        application.MarkViewed(Now).Should().BeFalse();

        application.ApplicationStatus.Should().Be(status, "opening a decided applicant must never undo the decision");
    }

    [Theory]
    [InlineData(VacancyApplicationStatus.Applied, VacancyApplicationStatus.Shortlisted)]
    [InlineData(VacancyApplicationStatus.Viewed, VacancyApplicationStatus.Hired)]
    [InlineData(VacancyApplicationStatus.Shortlisted, VacancyApplicationStatus.Hired)]
    [InlineData(VacancyApplicationStatus.Hired, VacancyApplicationStatus.Shortlisted)]
    public void Decide_BetweenStages_KeepsWhatTheWorkerSent(VacancyApplicationStatus from, VacancyApplicationStatus to)
    {
        var application = Application(from);

        application.Decide(to, Now).Should().BeTrue();

        application.ApplicationStatus.Should().Be(to);
        application.Answers.Should().OnlyContain(a => !a.IsDeleted);
        application.BusinessNote.Should().Be("Call Monday");
    }

    [Fact]
    public void Decide_Reject_DeletesWhatTheWorkerSentButKeepsTheApplication()
    {
        var application = Application(VacancyApplicationStatus.Viewed);

        application.Decide(VacancyApplicationStatus.Rejected, Now).Should().BeTrue();

        application.ApplicationStatus.Should().Be(VacancyApplicationStatus.Rejected);
        application.IsDeleted.Should().BeFalse("the worker still has to see that they were rejected");
        application.BusinessNote.Should().BeNull();
        application.Answers.Should().OnlyContain(a =>
            a.IsDeleted && a.AnswerText == null && a.FileKey == null && a.FileName == null);
    }

    [Theory]
    [InlineData(VacancyApplicationStatus.Shortlisted)]
    [InlineData(VacancyApplicationStatus.Hired)]
    [InlineData(VacancyApplicationStatus.Rejected)]
    public void Decide_AfterRejection_IsRefused(VacancyApplicationStatus to)
    {
        var act = () => Application(VacancyApplicationStatus.Rejected).Decide(to, Now);

        act.Should().Throw<DomainException>();
    }

    [Theory]
    [InlineData(VacancyApplicationStatus.Applied)]
    [InlineData(VacancyApplicationStatus.Viewed)]
    public void Decide_NewOrWaiting_IsNotADecision(VacancyApplicationStatus to)
    {
        var act = () => Application(VacancyApplicationStatus.Shortlisted).Decide(to, Now);

        act.Should().Throw<DomainException>("New and Waiting are reached by applying and opening, never chosen");
    }

    [Fact]
    public void Decide_SameStageAgain_ChangesNothing()
    {
        var application = Application(VacancyApplicationStatus.Shortlisted);

        application.Decide(VacancyApplicationStatus.Shortlisted, Now).Should().BeFalse();

        application.StatusChangedAt.Should().BeNull();
    }
}
