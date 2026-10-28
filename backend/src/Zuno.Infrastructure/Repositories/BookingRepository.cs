using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class BookingRepository(ZunoDbContext dbContext, IPlatformSettings platformSettings) : IBookingRepository
{
    /// <summary>Everything an order is shown with, except its crew — see <see cref="LoadCrewAsync"/>.</summary>
    private static IQueryable<Booking> IncludeOrder(IQueryable<Booking> query) => query
        .Include(b => b.CustomerProfile).ThenInclude(cp => cp.User)
        .Include(b => b.BusinessOwnerProfile).ThenInclude(bp => bp.User)
        .Include(b => b.BusinessService).ThenInclude(s => s.ServiceCategory)
        .Include(b => b.BusinessService).ThenInclude(s => s.ServiceSubCategory)
        .Include(b => b.BusinessService).ThenInclude(s => s.Media)
        .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.Media)
        .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.ServiceSubCategory)
        .Include(b => b.Address)
        // What the customer told the business about the job. Loaded on every read because it is
        // what the business staffs from, and a handful of short rows per order.
        .Include(b => b.ServiceAnswers)
        .Include(b => b.AgreementProposals)
        .Include(b => b.Rating);

    public async Task<Booking?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        var booking = await IncludeOrder(dbContext.Bookings).FirstOrDefaultAsync(b => b.Id == id, cancellationToken);
        if (booking is not null)
        {
            await LoadCrewAsync([booking.Id], cancellationToken);
        }

        return booking;
    }

    public Task<List<Booking>> GetByCustomerIdAsync(Guid customerProfileId, CancellationToken cancellationToken) =>
        LoadListAsync(dbContext.Bookings.Where(b => b.CustomerProfileId == customerProfileId), cancellationToken);

    public Task<List<Booking>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken) =>
        LoadListAsync(dbContext.Bookings.Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId), cancellationToken);

    public Task<List<Booking>> GetByWorkerIdAsync(Guid workerProfileId, CancellationToken cancellationToken) =>
        LoadListAsync(dbContext.Bookings.Where(b => b.WorkerAssignments.Any(a => a.WorkerProfileId == workerProfileId)), cancellationToken);

    public Task<List<Booking>> GetByBusinessAndCategoriesAsync(
        Guid businessOwnerProfileId,
        IReadOnlyCollection<Guid> serviceCategoryIds,
        CancellationToken cancellationToken) =>
        LoadListAsync(dbContext.Bookings.Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId
                && serviceCategoryIds.Contains(b.BusinessService.ServiceCategoryId)), cancellationToken);

    /// <summary>
    /// A list of orders with their details, newest first, at most the configured number.
    /// </summary>
    /// <remarks>
    /// Two steps on purpose. Filtering inside the full include graph let Postgres join every order in
    /// the table to its customer, business, service and crew before narrowing to the few it wanted —
    /// 15–30 s for one worker on a million orders. Picking the ids first is one indexed lookup; the
    /// details then load by primary key.
    /// </remarks>
    private async Task<List<Booking>> LoadListAsync(IQueryable<Booking> filtered, CancellationToken cancellationToken)
    {
        var ids = await filtered
            .OrderByDescending(b => b.CreatedDate)
            .Select(b => b.Id)
            .Take(platformSettings.Current.OrderListMax)
            .ToListAsync(cancellationToken);

        if (ids.Count == 0)
        {
            return [];
        }

        var bookings = await IncludeOrder(dbContext.Bookings)
            .Where(b => ids.Contains(b.Id))
            .ToListAsync(cancellationToken);
        await LoadCrewAsync(ids, cancellationToken);

        return [.. bookings.OrderByDescending(b => b.CreatedDate)];
    }

    /// <summary>
    /// The crew of the given orders, with each worker's account, payout details (to say whether they
    /// can be paid before a pay run starts) and wage changes (so a raised wage can say what it started
    /// at). Attached to the tracked orders by EF's relationship fix-up.
    /// </summary>
    /// <remarks>
    /// Its own query, filtered on the order ids directly. As an include of the order it became a join of
    /// every crew row in the table to its worker and user before the order filter applied — 5–6 s on
    /// 1.4 million crew rows; filtered here it is an index lookup.
    /// </remarks>
    private Task LoadCrewAsync(IReadOnlyCollection<Guid> bookingIds, CancellationToken cancellationToken) =>
        dbContext.BookingWorkerAssignments
            .Where(a => bookingIds.Contains(a.BookingId))
            .Include(a => a.WorkerProfile).ThenInclude(wp => wp.User)
            .Include(a => a.WorkerProfile).ThenInclude(wp => wp.PayoutDetail)
            .Include(a => a.SalaryAdjustments)
            .LoadAsync(cancellationToken);

    public void Add(Booking booking) => dbContext.Bookings.Add(booking);
}
