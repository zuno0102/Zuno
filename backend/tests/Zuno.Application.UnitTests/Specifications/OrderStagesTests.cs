using FluentAssertions;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Specifications;
using Zuno.Domain.ValueObjects;
using Xunit;

// Deliberately not ...UnitTests.Domain: that segment shadows Zuno.Domain for every other test
// file in the assembly.
namespace Zuno.Application.UnitTests.Specifications;

/// <summary>
/// Which stage an order or own event is in — the one decision behind every status chip and filter,
/// made on the server so the apps only look up its name.
/// </summary>
public class OrderStagesTests
{
    private static readonly BookingWageRollup Owing = new(PayeeCount: 2, PaidPayeeCount: 1, DisputedPayeeCount: 0, TotalPayable: 1600m, OutstandingAmount: 800m);
    private static readonly BookingWageRollup Square = new(PayeeCount: 2, PaidPayeeCount: 2, DisputedPayeeCount: 0, TotalPayable: 1600m, OutstandingAmount: 0m);

    private static BookingWorkerAssignment Mine(PaymentStatus payment, decimal? salary = 800m) => new()
    {
        AssignmentStatus = BookingWorkerAssignmentStatus.Accepted,
        AgreedSalaryAmount = salary,
        PaymentStatus = payment,
    };

    [Theory]
    [InlineData(BookingStatus.Pending, OrderStage.Active)]
    [InlineData(BookingStatus.Confirmed, OrderStage.Confirmed)]
    [InlineData(BookingStatus.Assigned, OrderStage.Confirmed)]
    [InlineData(BookingStatus.InProgress, OrderStage.InProgress)]
    [InlineData(BookingStatus.Cancelled, OrderStage.Cancelled)]
    public void ForBooking_EachStatusBeforeCompletion_MapsToItsStage(BookingStatus status, OrderStage expected)
    {
        OrderStages.ForBooking(status).Should().Be(expected);
    }

    [Fact]
    public void ForBooking_CompletedAndBusinessStillOwesTheCrew_IsAwaitingPayment()
    {
        OrderStages.ForBooking(BookingStatus.Completed, wages: Owing).Should().Be(OrderStage.AwaitingPayment);
    }

    [Fact]
    public void ForBooking_CompletedAndCrewPaid_IsCompleted()
    {
        OrderStages.ForBooking(BookingStatus.Completed, wages: Square).Should().Be(OrderStage.Completed);
    }

    [Fact]
    public void ForBooking_CompletedWithADisputedWage_IsStillAwaitingPayment()
    {
        var disputed = new BookingWageRollup(PayeeCount: 2, PaidPayeeCount: 2, DisputedPayeeCount: 1, TotalPayable: 1600m, OutstandingAmount: 0m);

        OrderStages.ForBooking(BookingStatus.Completed, wages: disputed).Should().Be(OrderStage.AwaitingPayment);
    }

    [Fact]
    public void ForBooking_CompletedAndNoWagesThroughZuno_IsCompleted()
    {
        OrderStages.ForBooking(BookingStatus.Completed, wages: BookingWageRollup.None).Should().Be(OrderStage.Completed);
    }

    [Fact]
    public void ForBooking_CompletedSeenByACustomer_IsCompleted_NotAGuessAboutWages()
    {
        // A customer is given neither their crew's wages nor a row of their own.
        OrderStages.ForBooking(BookingStatus.Completed).Should().Be(OrderStage.Completed);
    }

    [Theory]
    [InlineData(PaymentStatus.Unpaid)]
    [InlineData(PaymentStatus.Processing)]
    [InlineData(PaymentStatus.Failed)]
    [InlineData(PaymentStatus.AwaitingWorkerConfirmation)]
    public void ForBooking_CompletedAndMyWageNotReachedMe_IsAwaitingPayment(PaymentStatus payment)
    {
        OrderStages.ForBooking(BookingStatus.Completed, Mine(payment)).Should().Be(OrderStage.AwaitingPayment);
    }

    [Fact]
    public void ForBooking_CompletedAndMyWagePaid_IsCompleted_WhateverTheCrewIsOwed()
    {
        // The worker is answered from their own row, never the crew-wide figure.
        OrderStages.ForBooking(BookingStatus.Completed, Mine(PaymentStatus.Paid), Owing).Should().Be(OrderStage.Completed);
    }

    [Fact]
    public void ForBooking_CompletedAndMyRowCarriesNoMoney_IsCompleted()
    {
        // A mirror row from a hiring post sits at Unpaid for ever with nothing on it.
        OrderStages.ForBooking(BookingStatus.Completed, Mine(PaymentStatus.Unpaid, salary: null)).Should().Be(OrderStage.Completed);
    }

    private static HiringPost OwnEvent(
        DateTimeOffset? started = null,
        DateTimeOffset? completed = null,
        PaymentStatus? crewPayment = null) => new()
    {
        Title = "Catering crew",
        WorkStartedAt = started,
        WorkCompletedAt = completed,
        Applications = crewPayment is { } payment
            ? [new HiringPostApplication
            {
                ApplicationStatus = HiringPostApplicationStatus.Accepted,
                AgreedSalaryAmount = 700m,
                PaymentStatus = payment,
            }]
            : [],
    };

    private static readonly DateTimeOffset Earlier = new(2026, 10, 20, 9, 0, 0, TimeSpan.Zero);

    [Fact]
    public void ForOwnEvent_NotStarted_IsConfirmed()
    {
        OrderStages.ForOwnEvent(OwnEvent()).Should().Be(OrderStage.Confirmed);
    }

    [Fact]
    public void ForOwnEvent_WorkStarted_IsInProgress()
    {
        OrderStages.ForOwnEvent(OwnEvent(started: Earlier)).Should().Be(OrderStage.InProgress);
    }

    [Fact]
    public void ForOwnEvent_WorkDoneButCrewUnpaid_IsAwaitingPayment()
    {
        OrderStages.ForOwnEvent(OwnEvent(Earlier, Earlier.AddHours(6), PaymentStatus.Unpaid))
            .Should().Be(OrderStage.AwaitingPayment);
    }

    [Fact]
    public void ForOwnEvent_WorkDoneAndCrewPaid_IsCompleted()
    {
        OrderStages.ForOwnEvent(OwnEvent(Earlier, Earlier.AddHours(6), PaymentStatus.Paid))
            .Should().Be(OrderStage.Completed);
    }
}
