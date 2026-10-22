using System.Globalization;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Worker.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Worker.Queries.GetWorkerDashboard;

/// <summary>
/// Everything a worker's home screen shows, in two queries plus the shared earnings rule.
/// </summary>
/// <remarks>
/// A worker reaches work by two routes and both have to appear here, or the screen quietly omits
/// work they actually did: assignments against a customer's order, and hiring posts. Standalone
/// posts matter especially — they have no order behind them, so nothing in the booking tables knows
/// about them at all, and a dashboard built on bookings alone would show a worker who only ever does
/// standalone jobs an empty screen.
/// </remarks>
public class GetWorkerDashboardQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IWorkerEarningsService earningsService,
    IApplicationDbContext dbContext) : IRequestHandler<GetWorkerDashboardQuery, WorkerDashboardDto>
{
    /// <summary>Months of history on the chart.</summary>
    private const int TrendMonths = 6;

    /// <summary>
    /// Caps the rows sent, never the counts. A worker with forty upcoming jobs still sees forty in
    /// the figure; the list just stops being a useful thing to scroll.
    /// </summary>
    private const int DetailLimit = 25;

    /// <summary>Wages on their way but not arrived, matching <c>WorkerEarningsService</c>.</summary>
    private static readonly PaymentStatus[] StillComing =
    [
        PaymentStatus.Unpaid,
        PaymentStatus.Processing,
        PaymentStatus.Failed,
        PaymentStatus.AwaitingWorkerConfirmation,
    ];

    public async Task<WorkerDashboardDto> Handle(
        GetWorkerDashboardQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await dbContext.WorkerProfiles
            .Include(w => w.User)
            .Include(w => w.PayoutDetail)
            .FirstOrDefaultAsync(w => w.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var now = dateTimeProvider.UtcNow;

        // One flat pass per route, then every grouping below happens in memory over the two lists —
        // the same shape the business dashboard uses, and the reason this is two round trips rather
        // than one per section.
        var orderJobs = await dbContext.BookingWorkerAssignments
            .Where(a => a.WorkerProfileId == profile.Id
                && a.AssignmentStatus != BookingWorkerAssignmentStatus.Rejected)
            .Select(a => new OrderJobRow(
                a.BookingId,
                a.Booking.BusinessServiceVariant != null
                    ? a.Booking.BusinessServiceVariant.Name
                    : a.Booking.BusinessService.Name,
                a.Booking.BusinessOwnerProfile.BusinessName,
                a.Booking.ScheduledDate,
                a.Booking.Address.City,
                a.AgreedSalaryAmount,
                a.AgreedSalaryUnit,
                a.AssignmentStatus,
                a.Booking.BookingStatus,
                a.Booking.WorkStartedAt,
                a.Booking.CompletedAt,
                a.PaymentStatus))
            .ToListAsync(cancellationToken);

        var postJobs = await dbContext.HiringPostApplications
            .Where(a => a.WorkerProfileId == profile.Id
                && a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
            .Select(a => new PostJobRow(
                a.Id,
                a.HiringPost.Id,
                a.HiringPost.BookingId,
                a.HiringPost.Title,
                a.HiringPost.BusinessOwnerProfile.BusinessName,
                a.HiringPost.EventDate,
                a.HiringPost.Location,
                a.AgreedSalaryAmount ?? a.HiringPost.SalaryAmount,
                a.AgreedSalaryUnit ?? a.HiringPost.SalaryUnit,
                a.HiringPost.WorkStartedAt,
                a.HiringPost.WorkCompletedAt,
                a.PaymentStatus))
            .ToListAsync(cancellationToken);

        var openPostCount = await dbContext.HiringPosts
            .Where(Domain.Entities.HiringPost.StillHiringAt(now))
            .CountAsync(
                p => p.HiringPostStatus == HiringPostStatus.Open
                    && !p.Applications.Any(a => a.WorkerProfileId == profile.Id),
                cancellationToken);

        var earnings = await earningsService.GetAsync(profile.Id, cancellationToken);

        var inProgress = BuildInProgress(orderJobs, postJobs);
        var upcoming = BuildUpcoming(orderJobs, postJobs, now);
        var pending = BuildPendingPayments(postJobs);

        return new WorkerDashboardDto
        {
            Profile = profile.ToDto(earnings),

            InProgressCount = inProgress.Count,
            UpcomingCount = upcoming.Count,
            OpenHiringPostCount = openPostCount,
            InProgress = inProgress.Take(DetailLimit).ToList(),
            Upcoming = upcoming.Take(DetailLimit).ToList(),
            Completed = BuildCompleted(orderJobs, postJobs).Take(DetailLimit).ToList(),

            PendingPayments = pending,
            // Taken from the shared rule rather than summed from the rows above, so the total and
            // the worker's profile can never disagree on one screen.
            PendingPaymentTotal = earnings.OwedToYou,

            Trend = BuildTrend(orderJobs, postJobs, now),
        };
    }

    /// <summary>
    /// Work under way: started and not yet finished. Not "the day has arrived" — a job whose date
    /// has come but which nobody has started is still upcoming, and telling a worker it is in
    /// progress would have them think they were late.
    /// </summary>
    private static List<WorkerJobSummaryDto> BuildInProgress(
        List<OrderJobRow> orderJobs,
        List<PostJobRow> postJobs) =>
        orderJobs
            .Where(j => j.WorkStartedAt is not null
                && j.CompletedAt is null
                && j.OrderStatus != BookingStatus.Cancelled)
            .Select(ToSummary)
            .Concat(postJobs
                // Standalone only. A booking-linked post is the same job as its assignment above,
                // and listing both would show one evening's work twice.
                .Where(j => j.BookingId is null
                    && j.WorkStartedAt is not null
                    && j.WorkCompletedAt is null)
                .Select(ToSummary))
            .OrderBy(j => j.ScheduledDate)
            .ToList();


    /// <summary>
    /// Finished work, newest first.
    /// </summary>
    /// <remarks>
    /// Partitioned the same way the counts are: an assignment carries a job attached to an order —
    /// including one reached through a post, since accepting created the assignment — while an
    /// application counts only for a standalone post. Listing both unpartitioned would show the same
    /// evening's work twice.
    /// </remarks>
    private static List<WorkerJobSummaryDto> BuildCompleted(
        List<OrderJobRow> orderJobs,
        List<PostJobRow> postJobs) =>
        orderJobs
            .Where(j => j.OrderStatus == BookingStatus.Completed)
            .Select(ToSummary)
            .Concat(postJobs
                .Where(j => j.BookingId is null && j.WorkCompletedAt is not null)
                .Select(ToSummary))
            .OrderByDescending(j => j.ScheduledDate)
            .ToList();
    /// <summary>Still to come, soonest first — which is the order a worker plans in.</summary>
    private static List<WorkerJobSummaryDto> BuildUpcoming(
        List<OrderJobRow> orderJobs,
        List<PostJobRow> postJobs,
        DateTimeOffset now) =>
        orderJobs
            .Where(j => j.ScheduledDate > now
                && j.CompletedAt is null
                && j.OrderStatus != BookingStatus.Cancelled)
            .Select(ToSummary)
            .Concat(postJobs
                .Where(j => j.BookingId is null
                    && j.EventDate > now
                    && j.WorkCompletedAt is null)
                .Select(ToSummary))
            .OrderBy(j => j.ScheduledDate)
            .ToList();

    /// <summary>
    /// Finished work that has not been paid for, newest first.
    /// </summary>
    /// <remarks>
    /// Post wages only, and deliberately so: nothing in the app can move a hand-assigned wage off
    /// Unpaid yet, so those rows would sit here permanently with no action available on them. They
    /// still count toward what the worker has earned — they are simply not listed as chase-able.
    /// Every route in and out of a pending payment is keyed on the application id, which is why that
    /// is what travels with the row.
    /// </remarks>
    private static List<WorkerPendingPaymentDto> BuildPendingPayments(List<PostJobRow> postJobs) =>
        postJobs
            .Where(j => j.WorkCompletedAt is not null && StillComing.Contains(j.Payment))
            .OrderByDescending(j => j.WorkCompletedAt)
            .Select(j => new WorkerPendingPaymentDto
            {
                ApplicationId = j.ApplicationId,
                Title = j.Title,
                BusinessName = j.BusinessName,
                Amount = j.Amount,
                Unit = j.Unit.ToString(),
                PaymentStatus = j.Payment.ToString(),
                WorkCompletedAt = j.WorkCompletedAt,
            })
            .ToList();

    /// <summary>
    /// Every month in the window, including the empty ones — a chart that skips quiet months makes
    /// a worker's history look steadier than it was.
    /// </summary>
    /// <remarks>
    /// Both figures are filed by the month the <em>work finished</em>, not the month the money
    /// arrived. A wage paid six weeks late belongs to the job that earned it; filing it by payment
    /// date would move a worker's earnings into a month they did not work. It also means the two
    /// series line up, so a month can never show earnings against no jobs.
    /// </remarks>
    private static List<WorkerMonthlyEarningDto> BuildTrend(
        List<OrderJobRow> orderJobs,
        List<PostJobRow> postJobs,
        DateTimeOffset now)
    {
        // The count is partitioned to avoid crediting one job twice; the money is not, because a
        // wage only ever exists on one side. See WorkerEarningsRollup for why.
        var countable = orderJobs
            .Where(j => j.OrderStatus == BookingStatus.Completed)
            .Select(j => j.CompletedAt)
            .Concat(postJobs
                .Where(j => j.BookingId is null)
                .Select(j => j.WorkCompletedAt))
            .Where(at => at is not null)
            .Select(at => at!.Value)
            .ToList();

        var paid = orderJobs
            .Where(j => j.Payment == PaymentStatus.Paid && j.Amount is not null)
            .Select(j => (At: j.CompletedAt, Amount: j.Amount ?? 0m))
            .Concat(postJobs
                .Where(j => j.Payment == PaymentStatus.Paid)
                .Select(j => (At: j.WorkCompletedAt, Amount: j.Amount)))
            .Where(p => p.At is not null)
            .ToList();

        var months = new List<WorkerMonthlyEarningDto>();

        for (var offset = TrendMonths - 1; offset >= 0; offset--)
        {
            var point = now.AddMonths(-offset);

            months.Add(new WorkerMonthlyEarningDto
            {
                Label = CultureInfo.InvariantCulture.DateTimeFormat
                    .GetAbbreviatedMonthName(point.Month),
                Year = point.Year,
                Month = point.Month,
                JobsCompleted = countable.Count(at =>
                    at.Year == point.Year && at.Month == point.Month),
                Earned = paid
                    .Where(p => p.At!.Value.Year == point.Year
                        && p.At!.Value.Month == point.Month)
                    .Sum(p => p.Amount),
            });
        }

        return months;
    }

    private static WorkerJobSummaryDto ToSummary(OrderJobRow job) => new()
    {
        Id = job.BookingId,
        Source = "Booking",
        Title = job.Title,
        BusinessName = job.BusinessName,
        ScheduledDate = job.ScheduledDate,
        Location = job.City,
        MyWage = job.Amount,
        MyWageUnit = job.Unit?.ToString(),
        MyStatus = job.AssignmentStatus.ToString(),
        WorkStartedAt = job.WorkStartedAt,
        NeedsMyAnswer = job.AssignmentStatus == BookingWorkerAssignmentStatus.Assigned,
    };

    private static WorkerJobSummaryDto ToSummary(PostJobRow job) => new()
    {
        Id = job.PostId,
        Source = "Post",
        Title = job.Title,
        BusinessName = job.BusinessName,
        ScheduledDate = job.EventDate,
        Location = job.Location,
        MyWage = job.Amount,
        MyWageUnit = job.Unit.ToString(),
        // They accepted the offer to be here at all, so there is never an answer outstanding.
        MyStatus = nameof(HiringPostApplicationStatus.Accepted),
        WorkStartedAt = job.WorkStartedAt,
        NeedsMyAnswer = false,
    };

    /// <summary>A job reached by being put on a customer's order.</summary>
    private sealed record OrderJobRow(
        Guid BookingId,
        string Title,
        string BusinessName,
        DateTimeOffset ScheduledDate,
        string City,
        decimal? Amount,
        SalaryUnit? Unit,
        BookingWorkerAssignmentStatus AssignmentStatus,
        BookingStatus OrderStatus,
        DateTimeOffset? WorkStartedAt,
        DateTimeOffset? CompletedAt,
        PaymentStatus Payment);

    /// <summary>A job reached by taking a hiring post.</summary>
    private sealed record PostJobRow(
        Guid ApplicationId,
        Guid PostId,
        Guid? BookingId,
        string Title,
        string BusinessName,
        DateTimeOffset EventDate,
        string? Location,
        decimal Amount,
        SalaryUnit Unit,
        DateTimeOffset? WorkStartedAt,
        DateTimeOffset? WorkCompletedAt,
        PaymentStatus Payment);
}
