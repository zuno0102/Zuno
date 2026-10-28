using FluentAssertions;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.Vacancies;

/// <summary>
/// A vacancy is unseen until paid, live for its paid period, and can be stopped and started again
/// inside that period without paying. Renewing extends the period; it never decides to hire again.
/// </summary>
public class VacancyLifecycleTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 27, 10, 0, 0, TimeSpan.Zero);

    private static readonly VacancyFeePlan Plan = new() { Id = Guid.NewGuid(), Name = "Standard", Amount = 49m, ListingDays = 30 };

    private static Vacancy Unpaid() => new() { Id = Guid.NewGuid(), Title = "Receptionist" };

    private static Vacancy Live(DateTimeOffset? expiresAt = null)
    {
        var vacancy = Unpaid();
        vacancy.PriceWith(Plan);
        vacancy.RecordPayment("pay_1", Now.AddDays(-1));
        if (expiresAt is { } at)
        {
            vacancy.ExpiresAt = at;
        }

        return vacancy;
    }

    // ---- Being seen ------------------------------------------------------------------------------

    [Fact]
    public void IsLiveAt_WhenUnpaid_IsFalseAndNeedsPayment()
    {
        var vacancy = Unpaid();

        vacancy.IsLiveAt(Now).Should().BeFalse();
        vacancy.NeedsPaymentAt(Now).Should().BeTrue();
    }

    [Theory]
    [InlineData(1, true)]   // a second before the end: live
    [InlineData(0, false)]  // exactly at the end: over
    [InlineData(-1, false)]
    public void IsLiveAt_AroundExpiry_EndsExactlyAtExpiry(int secondsLeft, bool expected)
    {
        var vacancy = Live(Now.AddSeconds(secondsLeft));

        vacancy.IsLiveAt(Now).Should().Be(expected);
        vacancy.NeedsPaymentAt(Now).Should().Be(!expected);
    }

    [Theory]
    [InlineData(VacancyStatus.Open, 1, true)]
    [InlineData(VacancyStatus.Open, -1, false)]
    [InlineData(VacancyStatus.Stopped, 1, false)]
    [InlineData(VacancyStatus.AwaitingPayment, 1, false)]
    public void LiveAt_TheDatabaseFormAgreesWithTheEntity(VacancyStatus status, int daysLeft, bool expected)
    {
        var vacancy = Live(Now.AddDays(daysLeft));
        vacancy.VacancyStatus = status;

        var sql = Vacancy.LiveAt(Now).Compile();

        sql(vacancy).Should().Be(expected).And.Be(vacancy.IsLiveAt(Now));
    }

    // ---- Paying ----------------------------------------------------------------------------------

    [Fact]
    public void RecordPayment_FirstTime_GoesLiveForThePlansDays()
    {
        var vacancy = Unpaid();
        vacancy.PriceWith(Plan);
        vacancy.PendingOrderId = "order_1";

        vacancy.RecordPayment("pay_1", Now);

        vacancy.VacancyStatus.Should().Be(VacancyStatus.Open);
        vacancy.ExpiresAt.Should().Be(Now.AddDays(30));
        vacancy.PublishedAt.Should().Be(Now);
        vacancy.PendingOrderId.Should().BeNull();
        vacancy.PaidCount.Should().Be(1);
        vacancy.LastPaymentId.Should().Be("pay_1");
    }

    [Fact]
    public void RecordPayment_RenewingEarly_ExtendsFromTheOldExpiry()
    {
        var vacancy = Live(Now.AddDays(5));

        vacancy.RecordPayment("pay_2", Now);

        vacancy.ExpiresAt.Should().Be(Now.AddDays(35), "days already paid for are never thrown away");
    }

    [Fact]
    public void RecordPayment_AfterExpiry_StartsFromNow()
    {
        var vacancy = Live(Now.AddDays(-3));

        vacancy.RecordPayment("pay_2", Now);

        vacancy.ExpiresAt.Should().Be(Now.AddDays(30));
        vacancy.PublishedAt.Should().Be(Now.AddDays(-1), "first published stays the first time");
    }

    [Fact]
    public void RecordPayment_WhenStopped_StaysStopped()
    {
        var vacancy = Live(Now.AddDays(-1));
        vacancy.VacancyStatus = VacancyStatus.Stopped;

        vacancy.RecordPayment("pay_2", Now);

        vacancy.VacancyStatus.Should().Be(VacancyStatus.Stopped, "paying is not deciding to hire again");
        vacancy.CanResumeAt(Now).Should().BeTrue();
    }

    [Fact]
    public void RecordPayment_WithNoPricedOrder_Throws()
    {
        var act = () => Unpaid().RecordPayment("pay_1", Now);

        act.Should().Throw<DomainException>();
    }

    [Fact]
    public void PriceWith_SameTerms_KeepsTheOrderSoATapTwiceIsOneCharge()
    {
        var vacancy = Unpaid();
        vacancy.PriceWith(Plan);
        vacancy.PendingOrderId = "order_1";

        vacancy.PriceWith(Plan);

        vacancy.PendingOrderId.Should().Be("order_1");
    }

    [Fact]
    public void PriceWith_NewPrice_DropsTheOldOrder()
    {
        var vacancy = Unpaid();
        vacancy.PriceWith(Plan);
        vacancy.PendingOrderId = "order_1";

        vacancy.PriceWith(new VacancyFeePlan { Id = Plan.Id, Name = "Standard", Amount = 99m, ListingDays = 30 });

        vacancy.PendingOrderId.Should().BeNull("the old order would charge the old price");
        vacancy.FeeAmount.Should().Be(99m);
    }

    [Fact]
    public void NextPaymentKey_FitsRazorpaysReceiptAndChangesPerPeriod()
    {
        var vacancy = Unpaid();
        var first = vacancy.NextPaymentKey;
        vacancy.PaidCount = 12;

        first.Length.Should().BeLessThanOrEqualTo(40);
        vacancy.NextPaymentKey.Should().NotBe(first);
        vacancy.NextPaymentKey.Length.Should().BeLessThanOrEqualTo(40);
    }

    // ---- Stopping and starting again -----------------------------------------------------------------

    [Fact]
    public void StopHiring_WhenOpen_HidesWithoutDeleting()
    {
        var vacancy = Live(Now.AddDays(10));

        vacancy.StopHiring(Now);

        vacancy.VacancyStatus.Should().Be(VacancyStatus.Stopped);
        vacancy.HiringStoppedAt.Should().Be(Now);
        vacancy.IsLiveAt(Now).Should().BeFalse();
        vacancy.IsDeleted.Should().BeFalse();
    }

    [Theory]
    [InlineData(VacancyStatus.Stopped)]
    [InlineData(VacancyStatus.AwaitingPayment)]
    public void StopHiring_WhenNotOpen_Throws(VacancyStatus status)
    {
        var vacancy = Live(Now.AddDays(10));
        vacancy.VacancyStatus = status;

        var act = () => vacancy.StopHiring(Now);

        act.Should().Throw<DomainException>();
    }

    [Fact]
    public void ResumeHiring_InsideThePaidPeriod_IsFree()
    {
        var vacancy = Live(Now.AddDays(10));
        vacancy.StopHiring(Now);

        vacancy.ResumeHiring(Now);

        vacancy.VacancyStatus.Should().Be(VacancyStatus.Open);
        vacancy.HiringStoppedAt.Should().BeNull();
        vacancy.PaidCount.Should().Be(1);
    }

    [Fact]
    public void ResumeHiring_AfterThePeriodEnded_AsksForPayment()
    {
        var vacancy = Live(Now.AddDays(10));
        vacancy.StopHiring(Now);
        vacancy.ExpiresAt = Now;

        var act = () => vacancy.ResumeHiring(Now);

        act.Should().Throw<DomainException>().WithMessage("*Pay the listing fee*");
        vacancy.VacancyStatus.Should().Be(VacancyStatus.Stopped);
    }

    [Fact]
    public void ResumeHiring_WhenAlreadyOpen_Throws()
    {
        var act = () => Live(Now.AddDays(10)).ResumeHiring(Now);

        act.Should().Throw<DomainException>();
    }

    // ---- Personal data -------------------------------------------------------------------------------

    [Fact]
    public void ErasePersonalData_WipesEveryAnswerAndFileReference()
    {
        var application = new VacancyApplication { BusinessNote = "Good fit" };
        application.Answers.Add(new VacancyApplicationAnswer { AnswerText = "Yes", FileKey = null });
        application.Answers.Add(new VacancyApplicationAnswer { FileKey = "vacancies/a/b/c.pdf", FileName = "Aadhaar card.pdf" });

        application.ErasePersonalData();

        application.IsDeleted.Should().BeTrue();
        application.BusinessNote.Should().BeNull();
        application.Answers.Should().OnlyContain(a =>
            a.IsDeleted && a.AnswerText == null && a.FileKey == null && a.FileName == null);
    }

    // ---- Reference data and settings ---------------------------------------------------------------

    [Theory]
    [InlineData("pdf", true)]
    [InlineData(".PDF", true)]
    [InlineData("jpeg", true)]
    [InlineData("webp", false)]
    [InlineData("exe", false)]
    [InlineData("", false)]
    public void AcceptsFile_ReadsTheConfiguredAllowList(string extension, bool expected)
    {
        var settings = new VacancySettings { AllowedFileExtensions = ["pdf", "jpg", "jpeg", "png"] };

        settings.AcceptsFile(extension).Should().Be(expected);
    }

    [Theory]
    [InlineData(null, 20)]
    [InlineData(0, 20)]
    [InlineData(-5, 20)]
    [InlineData(10, 10)]
    [InlineData(50, 50)]
    [InlineData(1000, 50)]
    public void PageSize_IsClampedToTheConfiguredBounds(int? requested, int expected)
    {
        var settings = new VacancySettings { DefaultPageSize = 20, MaxPageSize = 50 };

        settings.PageSize(requested).Should().Be(expected);
    }
}
