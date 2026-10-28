using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Common.Services;

/// <inheritdoc />
public class BusinessTrustService(IApplicationDbContext dbContext) : IBusinessTrustService
{
    public async Task<BusinessTrustDto> GetAsync(
        Guid businessOwnerProfileId,
        CancellationToken cancellationToken = default)
    {
        // One pass over the hires, pulled with their posts because almost every worker-facing
        // figure compares what was agreed against what was advertised.
        var hires = await dbContext.HiringPostApplications
            .Where(a => a.HiringPost.BusinessOwnerProfileId == businessOwnerProfileId)
            .Where(a => a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
            .Select(a => new HireRow
            {
                WorkerProfileId = a.WorkerProfileId,
                AgreedSalary = a.AgreedSalaryAmount,
                PostedSalary = a.HiringPost.SalaryAmount,
                SalaryUnit = a.HiringPost.SalaryUnit,
                PaymentStatus = a.PaymentStatus,
                PaidAt = a.PaidAt,
                WorkCompletedAt = a.HiringPost.WorkCompletedAt,
            })
            .ToListAsync(cancellationToken);

        var profile = await dbContext.BusinessOwnerProfiles
            .Where(p => p.Id == businessOwnerProfileId)
            .Select(p => new
            {
                p.CompletedJobCount,
                p.CustomerRatingAverage,
                p.CustomerReviewCount,
            })
            .FirstOrDefaultAsync(cancellationToken);

        var repeatCustomers = await dbContext.Bookings
            .Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId)
            .GroupBy(b => b.CustomerProfileId)
            .CountAsync(g => g.Count() > 1, cancellationToken);

        return new BusinessTrustDto
        {
            Customers = new CustomerFacingTrustDto
            {
                EventsCompleted = profile?.CompletedJobCount ?? 0,
                RatingAverage = profile?.CustomerRatingAverage,
                ReviewCount = profile?.CustomerReviewCount ?? 0,
                RepeatCustomers = repeatCustomers,
            },
            Workers = BuildWorkerFacing(hires),
        };
    }

    private static WorkerFacingTrustDto BuildWorkerFacing(List<HireRow> hires)
    {
        // A ₹0 wage is a posting mistake rather than a rate, and averaging it in would drag the
        // headline figure below anything the business has ever actually offered.
        var priced = hires.Where(h => h.AgreedSalary is > 0m).ToList();
        var salaries = priced.Select(h => h.AgreedSalary!.Value).ToList();

        // Only crew whose work is finished can meaningfully be "awaiting payment" — everyone else
        // simply is not due yet, and counting them would libel a business that pays promptly.
        var due = hires.Where(h => h.WorkCompletedAt is not null).ToList();

        var turnarounds = hires
            .Where(h => h.PaymentStatus == PaymentStatus.Paid
                && h.PaidAt is not null
                && h.WorkCompletedAt is not null)
            .Select(h => (decimal)(h.PaidAt!.Value - h.WorkCompletedAt!.Value).TotalHours)
            .Where(hours => hours >= 0m)
            .OrderBy(hours => hours)
            .ToList();

        var byWorker = hires.GroupBy(h => h.WorkerProfileId).ToList();

        return new WorkerFacingTrustDto
        {
            AverageSalary = salaries.Count > 0 ? Math.Round(salaries.Average(), 0) : null,
            LowestSalary = salaries.Count > 0 ? salaries.Min() : null,
            HighestSalary = salaries.Count > 0 ? salaries.Max() : null,
            SalaryUnit = MostCommonUnit(priced),
            TotalHires = hires.Count,

            // "Met or beat" rather than "equalled": the salary ratchet only ever raises an agreed
            // wage, so paying above the advertised rate is still keeping the promise.
            PaidPostedRateCount = priced.Count(h => h.AgreedSalary >= h.PostedSalary),
            RaisedPayCount = priced.Count(h => h.AgreedSalary > h.PostedSalary),

            CrewsPaid = due.Count(h => h.PaymentStatus == PaymentStatus.Paid),
            CrewsAwaitingPayment = due.Count(h => h.PaymentStatus is PaymentStatus.Unpaid
                or PaymentStatus.Processing
                or PaymentStatus.Failed
                or PaymentStatus.AwaitingWorkerConfirmation),

            TypicalHoursToPay = Median(turnarounds),

            DistinctWorkers = byWorker.Count,
            RepeatHires = byWorker.Count(g => g.Count() > 1),

            OpenDisputes = hires.Count(h => h.PaymentStatus == PaymentStatus.Disputed),
            OverdueWages = due
                .Where(h => h.PaymentStatus is PaymentStatus.Unpaid or PaymentStatus.Failed)
                .Sum(h => h.AgreedSalary ?? 0m),
        };
    }

    private static string? MostCommonUnit(List<HireRow> hires) => hires
        .GroupBy(h => h.SalaryUnit)
        .OrderByDescending(g => g.Count())
        .Select(g => g.Key.ToString())
        .FirstOrDefault();

    private static decimal? Median(List<decimal> sorted)
    {
        if (sorted.Count == 0)
        {
            return null;
        }

        var middle = sorted.Count / 2;
        var value = sorted.Count % 2 == 1
            ? sorted[middle]
            : (sorted[middle - 1] + sorted[middle]) / 2m;

        return Math.Round(value, 1);
    }

    /// <summary>Flattened hire row, so the aggregation runs in memory over one query's results.</summary>
    private sealed class HireRow
    {
        public Guid WorkerProfileId { get; init; }

        public decimal? AgreedSalary { get; init; }

        public decimal PostedSalary { get; init; }

        public SalaryUnit SalaryUnit { get; init; }

        public PaymentStatus PaymentStatus { get; init; }

        public DateTimeOffset? PaidAt { get; init; }

        public DateTimeOffset? WorkCompletedAt { get; init; }
    }
}
