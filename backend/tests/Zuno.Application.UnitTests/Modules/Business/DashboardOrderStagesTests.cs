using FluentAssertions;
using Zuno.Application.Modules.Business.Queries.GetBusinessDashboard;
using Zuno.Domain.Enums;

namespace Zuno.Application.UnitTests.Modules.Business;

/// <summary>
/// Which business dashboard tile an order counts under: Upcoming is confirmed work only,
/// Finished is event, crew, work and payment all done, and Awaiting payment sits between them.
/// </summary>
public class DashboardOrderStagesTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 21, 9, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset NextWeek = Now.AddDays(7);
    private static readonly DateTimeOffset LastWeek = Now.AddDays(-7);

    [Fact]
    public void A_request_the_business_has_not_confirmed_is_not_upcoming()
    {
        DashboardOrderStages.Of(BookingStatus.Pending, NextWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.None);
    }

    [Theory]
    [InlineData(BookingStatus.Confirmed)]
    [InlineData(BookingStatus.Assigned)]
    public void Confirmed_work_with_its_date_ahead_is_upcoming(BookingStatus status)
    {
        DashboardOrderStages.Of(status, NextWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.Upcoming);
    }

    [Fact]
    public void A_confirmed_order_whose_day_has_come_is_active_not_upcoming()
    {
        DashboardOrderStages.Of(BookingStatus.Confirmed, LastWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.None);
    }

    [Fact]
    public void Work_under_way_is_not_upcoming_even_before_its_date()
    {
        DashboardOrderStages.Of(BookingStatus.InProgress, NextWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.None);
    }

    [Fact]
    public void Completed_work_with_a_worker_still_unpaid_is_awaiting_payment_not_finished()
    {
        DashboardOrderStages.Of(BookingStatus.Completed, LastWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.AwaitingPayment);
    }

    [Fact]
    public void Completed_and_everyone_paid_is_finished()
    {
        DashboardOrderStages.Of(BookingStatus.Completed, LastWeek, isSettled: true, Now)
            .Should().Be(DashboardOrderStage.Finished);
    }

    [Fact]
    public void A_cancelled_order_is_only_ever_cancelled()
    {
        DashboardOrderStages.Of(BookingStatus.Cancelled, NextWeek, isSettled: false, Now)
            .Should().Be(DashboardOrderStage.Cancelled);
    }
}
