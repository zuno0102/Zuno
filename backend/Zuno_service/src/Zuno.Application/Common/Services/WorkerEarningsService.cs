using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Services;

/// <inheritdoc />
public class WorkerEarningsService(IApplicationDbContext dbContext) : IWorkerEarningsService
{
    /// <summary>
    /// Wages on their way but not arrived. Paid is excluded because it has arrived; Disputed is
    /// excluded because it is reported separately and counting it as owed as well would state the
    /// same money twice on one screen.
    /// </summary>
    private static readonly PaymentStatus[] StillComing =
    [
        PaymentStatus.Unpaid,
        PaymentStatus.Processing,
        PaymentStatus.Failed,
        PaymentStatus.AwaitingWorkerConfirmation,
    ];

    public async Task<WorkerEarningsRollup> GetAsync(
        Guid workerProfileId,
        CancellationToken cancellationToken = default)
    {
        // Two projections rather than one graph, for the same reason BookingWageService does it:
        // this produces eight numbers and loading the entities behind them would be many times
        // the work. Kept as flat rows so every rule below is visible in one place.
        var applications = await dbContext.HiringPostApplications
            .Where(a => a.WorkerProfileId == workerProfileId)
            .Select(a => new ApplicationRow(
                a.ApplicationStatus,
                a.PaymentStatus,
                a.AgreedSalaryAmount,
                a.HiringPost.BusinessOwnerProfileId,
                a.HiringPost.BookingId,
                a.HiringPost.WorkCompletedAt))
            .ToListAsync(cancellationToken);

        var assignments = await dbContext.BookingWorkerAssignments
            .Where(a => a.WorkerProfileId == workerProfileId
                && a.AssignmentStatus != BookingWorkerAssignmentStatus.Rejected)
            .Select(a => new AssignmentRow(
                a.PaymentStatus,
                a.AgreedSalaryAmount,
                a.Booking.BusinessOwnerProfileId,
                a.Booking.BookingStatus == BookingStatus.Completed))
            .ToListAsync(cancellationToken);

        var hires = applications
            .Where(a => a.Status == HiringPostApplicationStatus.Accepted)
            .ToList();

        // ---- Money: summed straight across both routes -------------------------------------
        //
        // Safe because a wage is only ever written in one of the two places. When a worker accepts
        // a post offer on an order, the mirror assignment is created without a salary, so the same
        // money cannot appear twice.
        var paidAmounts = hires
            .Where(a => a.Payment == PaymentStatus.Paid)
            .Select(a => a.Amount ?? 0m)
            .Concat(assignments
                .Where(a => a.Amount != null && a.Payment == PaymentStatus.Paid)
                .Select(a => a.Amount ?? 0m))
            .ToList();

        // Post wages only. Nothing in the app can yet move a hand-assigned wage off Unpaid, so
        // including those would leave a worker staring at an amount that never clears.
        var owed = hires
            .Where(a => a.WorkCompletedAt is not null && StillComing.Contains(a.Payment))
            .Sum(a => a.Amount ?? 0m);

        // ---- Counts: partitioned, because these DO duplicate --------------------------------
        //
        // The assignment counts a job attached to an order — including one the worker reached
        // through a post, since accepting created the assignment. An application counts on its own
        // only for a standalone post, which has no order to count through. Exactly the split
        // BookingWageRules uses to stop a business's record double-counting.
        var jobsFromOrders = assignments.Count(a => a.OrderCompleted);
        var jobsFromStandalonePosts = hires.Count(a =>
            a.BookingId is null && a.WorkCompletedAt is not null);

        return new WorkerEarningsRollup(
            TotalEarned: paidAmounts.Sum(),
            OwedToYou: owed,
            JobsCompleted: jobsFromOrders + jobsFromStandalonePosts,
            JobsPaid: paidAmounts.Count,
            AverageSalary: paidAmounts.Count > 0
                ? Math.Round(paidAmounts.Average(), 0)
                : null,
            // Distinct across both routes: the same business hiring somebody twice, once each way,
            // is still one business.
            BusinessesWorkedFor: hires.Select(a => a.BusinessOwnerProfileId)
                .Concat(assignments.Select(a => a.BusinessOwnerProfileId))
                .Distinct()
                .Count(),
            OffersDeclined: applications.Count(a =>
                a.Status == HiringPostApplicationStatus.Declined),
            OpenDisputes: hires.Count(a => a.Payment == PaymentStatus.Disputed));
    }

    /// <summary>A hiring-post application, flattened to only what the rules above read.</summary>
    private sealed record ApplicationRow(
        HiringPostApplicationStatus Status,
        PaymentStatus Payment,
        decimal? Amount,
        Guid BusinessOwnerProfileId,
        Guid? BookingId,
        DateTimeOffset? WorkCompletedAt);

    /// <summary>A worker put on an order, flattened the same way.</summary>
    private sealed record AssignmentRow(
        PaymentStatus Payment,
        decimal? Amount,
        Guid BusinessOwnerProfileId,
        bool OrderCompleted);
}
