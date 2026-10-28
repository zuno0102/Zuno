using FluentAssertions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.UnitTests.Modules.HiringPosts;

/// <summary>
/// A business can raise one crew member's agreed salary for extra work, before payment. The job's
/// total is the sum of each worker's own figure, so the pay run splits it exactly as agreed.
/// </summary>
public class SalaryRaiseTests
{
    private const decimal PostedSalary = 1000m;

    private static HiringPostApplication Worker(
        HiringPostApplicationStatus status = HiringPostApplicationStatus.Accepted,
        PaymentStatus payment = PaymentStatus.Unpaid,
        decimal? agreed = PostedSalary) => new()
        {
            Id = Guid.NewGuid(),
            WorkerProfileId = Guid.NewGuid(),
            ApplicationStatus = status,
            AgreedSalaryAmount = agreed,
            AgreedSalaryUnit = SalaryUnit.PerEvent,
            PaymentStatus = payment,
        };

    private static HiringPost CrewOf(int count)
    {
        var post = new HiringPost { Id = Guid.NewGuid(), WorkersNeeded = count, SalaryAmount = PostedSalary };
        for (var i = 0; i < count; i++)
        {
            post.Applications.Add(Worker());
        }

        return post;
    }

    private static PayoutBatch RunFor(HiringPost post)
    {
        var batch = new PayoutBatch { HiringPostId = post.Id };
        foreach (var a in post.Applications)
        {
            batch.Items.Add(new PayoutBatchItem { HiringPostApplicationId = a.Id, Amount = a.AgreedSalaryAmount!.Value });
        }

        return batch;
    }

    // ---- The worked example -----------------------------------------------------------------

    [Fact]
    public void RaiseSalary_OneOfFiveWorkersRaisedTo1300_TotalIs5300AndSplitIsPerWorker()
    {
        var post = CrewOf(5);
        post.TotalPayable.Should().Be(5000m);
        var raised = post.Applications.First();

        raised.RaiseSalary(1300m, "Stayed 3 extra hours");

        post.TotalPayable.Should().Be(5300m);
        post.OutstandingAmount.Should().Be(5300m);
        post.Payees.Single(p => p.Id == raised.Id).Amount.Should().Be(1300m);
        post.Payees.Where(p => p.Id != raised.Id).Should().HaveCount(4)
            .And.OnlyContain(p => p.Amount == PostedSalary);
    }

    [Fact]
    public void RaiseSalary_HappyPath_RecordsAdjustmentAndUpdatesAgreedAmount()
    {
        var worker = Worker();

        var adjustment = worker.RaiseSalary(1300m, "Extra hours");

        worker.AgreedSalaryAmount.Should().Be(1300m);
        adjustment.PreviousAmount.Should().Be(PostedSalary);
        adjustment.NewAmount.Should().Be(1300m);
        adjustment.Reason.Should().Be("Extra hours");
        adjustment.HiringPostApplicationId.Should().Be(worker.Id);
        worker.SalaryAdjustments.Should().ContainSingle().Which.Should().BeSameAs(adjustment);
    }

    [Fact]
    public void RaiseSalary_RaisedTwice_KeepsBothAdjustmentsInOrder()
    {
        var worker = Worker();

        worker.RaiseSalary(1200m, null);
        worker.RaiseSalary(1300m, null);

        worker.AgreedSalaryAmount.Should().Be(1300m);
        worker.SalaryAdjustments.Select(a => (a.PreviousAmount, a.NewAmount))
            .Should().Equal((1000m, 1200m), (1200m, 1300m));
    }

    // ---- Boundaries --------------------------------------------------------------------------

    [Theory]
    [InlineData(1000)]
    [InlineData(999.99)]
    [InlineData(500)]
    public void RaiseSalary_NotAboveCurrentAmount_Throws(decimal newAmount)
    {
        var worker = Worker();

        var act = () => worker.RaiseSalary(newAmount, null);

        act.Should().Throw<DomainException>().WithMessage("*can only be increased*");
        worker.AgreedSalaryAmount.Should().Be(PostedSalary);
        worker.SalaryAdjustments.Should().BeEmpty();
    }

    [Fact]
    public void RaiseSalary_JustAboveCurrentAmount_IsAllowed()
    {
        var worker = Worker();

        worker.RaiseSalary(1000.01m, null);

        worker.AgreedSalaryAmount.Should().Be(1000.01m);
    }

    // ---- Before payment only -----------------------------------------------------------------

    [Theory]
    [InlineData(PaymentStatus.Processing)]
    [InlineData(PaymentStatus.Paid)]
    [InlineData(PaymentStatus.Failed)]
    [InlineData(PaymentStatus.Disputed)]
    [InlineData(PaymentStatus.AwaitingWorkerConfirmation)]
    public void RaiseSalary_OncePaymentHasStarted_Throws(PaymentStatus payment)
    {
        var worker = Worker(payment: payment);

        var act = () => worker.RaiseSalary(1300m, null);

        act.Should().Throw<DomainException>().WithMessage("*payment has already started*");
        worker.AgreedSalaryAmount.Should().Be(PostedSalary);
        worker.SalaryAdjustments.Should().BeEmpty();
    }

    // ---- State -------------------------------------------------------------------------------

    [Fact]
    public void RaiseSalary_OfferStillPending_IsAllowed()
    {
        var worker = Worker(HiringPostApplicationStatus.Confirmed);

        worker.RaiseSalary(1300m, null);

        worker.AgreedSalaryAmount.Should().Be(1300m);
    }

    [Theory]
    [InlineData(HiringPostApplicationStatus.Applied)]
    [InlineData(HiringPostApplicationStatus.Rejected)]
    [InlineData(HiringPostApplicationStatus.Declined)]
    public void RaiseSalary_WorkerNotOnTheCrew_Throws(HiringPostApplicationStatus status)
    {
        var worker = Worker(status);

        var act = () => worker.RaiseSalary(1300m, null);

        act.Should().Throw<DomainException>().WithMessage("*accepted*");
        worker.SalaryAdjustments.Should().BeEmpty();
    }

    [Fact]
    public void RaiseSalary_NoAgreedSalary_Throws()
    {
        var worker = Worker(agreed: null);

        var act = () => worker.RaiseSalary(1300m, null);

        act.Should().Throw<DomainException>().WithMessage("*no agreed salary*");
    }

    // ---- An unpaid pay run opened before the raise -------------------------------------------

    [Fact]
    public void PaysSameWagesAs_NothingChanged_ReturnsTrue()
    {
        var post = CrewOf(5);

        RunFor(post).PaysSameWagesAs(RunFor(post)).Should().BeTrue();
    }

    [Fact]
    public void PaysSameWagesAs_SalaryRaisedSinceRunOpened_ReturnsFalse()
    {
        var post = CrewOf(5);
        var openedBeforeRaise = RunFor(post);

        post.Applications.First().RaiseSalary(1300m, null);

        openedBeforeRaise.PaysSameWagesAs(RunFor(post)).Should().BeFalse();
    }

    [Fact]
    public void PaysSameWagesAs_DifferentCrew_ReturnsFalse()
    {
        var post = CrewOf(5);
        var openedEarlier = RunFor(post);

        post.Applications.Add(Worker());

        openedEarlier.PaysSameWagesAs(RunFor(post)).Should().BeFalse();
    }
}
