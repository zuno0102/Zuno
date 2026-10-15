using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Services;

/// <inheritdoc />
public class BookingWageService(IApplicationDbContext dbContext) : IBookingWageService
{
    public async Task<BookingWageRollup> GetAsync(
        Guid bookingId,
        CancellationToken cancellationToken = default)
    {
        var many = await GetManyAsync([bookingId], cancellationToken);
        return many.GetValueOrDefault(bookingId, BookingWageRollup.None);
    }

    public async Task<IReadOnlyDictionary<Guid, BookingWageRollup>> GetManyAsync(
        IReadOnlyCollection<Guid> bookingIds,
        CancellationToken cancellationToken = default)
    {
        if (bookingIds.Count == 0)
        {
            return new Dictionary<Guid, BookingWageRollup>();
        }

        // Two grouped queries, not a graph of posts and crews. A list screen asks for every order
        // at once, and loading the entities would be a query per order to produce five integers.
        //
        // Two, because a job's crew can come from two places: workers hired through a post, and
        // workers the business put on the job itself. Both are owed the same money and both have
        // to appear in the same total, or the business is told it owes less than it does.
        var fromPosts = await dbContext.HiringPostApplications
            .Where(a => a.HiringPost.BookingId != null
                && bookingIds.Contains(a.HiringPost.BookingId!.Value)
                && a.ApplicationStatus == HiringPostApplicationStatus.Accepted)
            .GroupBy(a => a.HiringPost.BookingId!.Value)
            .Select(g => new WageRow(
                g.Key,
                g.Count(),
                g.Count(a => a.PaymentStatus == PaymentStatus.Paid),
                g.Count(a => a.PaymentStatus == PaymentStatus.Disputed),
                g.Sum(a => a.AgreedSalaryAmount ?? 0m),
                g.Sum(a => a.PaymentStatus == PaymentStatus.Paid
                    ? 0m
                    : a.AgreedSalaryAmount ?? 0m)))
            .ToListAsync(cancellationToken);

        // Only assignments carrying a wage. A worker with no salary recorded is paid outside Zuno
        // — a regular on a monthly wage — and counting them as a ₹0 payee would leave an order
        // reading "0 of 3 paid" forever with nothing anyone could do about it.
        var fromAssignments = await dbContext.BookingWorkerAssignments
            .Where(a => bookingIds.Contains(a.BookingId)
                && a.AgreedSalaryAmount != null
                && a.AssignmentStatus != BookingWorkerAssignmentStatus.Rejected)
            .GroupBy(a => a.BookingId)
            .Select(g => new WageRow(
                g.Key,
                g.Count(),
                g.Count(a => a.PaymentStatus == PaymentStatus.Paid),
                g.Count(a => a.PaymentStatus == PaymentStatus.Disputed),
                g.Sum(a => a.AgreedSalaryAmount ?? 0m),
                g.Sum(a => a.PaymentStatus == PaymentStatus.Paid
                    ? 0m
                    : a.AgreedSalaryAmount ?? 0m)))
            .ToListAsync(cancellationToken);

        return fromPosts
            .Concat(fromAssignments)
            .GroupBy(r => r.BookingId)
            .ToDictionary(
                g => g.Key,
                g => new BookingWageRollup(
                    g.Sum(r => r.PayeeCount),
                    g.Sum(r => r.PaidPayeeCount),
                    g.Sum(r => r.DisputedPayeeCount),
                    g.Sum(r => r.TotalPayable),
                    g.Sum(r => r.OutstandingAmount)));
    }

    /// <summary>One source's contribution to an order's wages, before the two are added up.</summary>
    private sealed record WageRow(
        Guid BookingId,
        int PayeeCount,
        int PaidPayeeCount,
        int DisputedPayeeCount,
        decimal TotalPayable,
        decimal OutstandingAmount);
}
