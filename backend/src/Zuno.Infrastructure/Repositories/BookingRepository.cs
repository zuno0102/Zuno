using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class BookingRepository(ZunoDbContext dbContext) : IBookingRepository
{
    private static IQueryable<Booking> IncludeGraph(IQueryable<Booking> query) => query
        .Include(b => b.CustomerProfile).ThenInclude(cp => cp.User)
        .Include(b => b.BusinessOwnerProfile).ThenInclude(bp => bp.User)
        .Include(b => b.BusinessService).ThenInclude(s => s.ServiceCategory)
        .Include(b => b.BusinessService).ThenInclude(s => s.Media)
        .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.Media)
        .Include(b => b.BusinessServiceVariant).ThenInclude(v => v!.ServiceSubCategory)
        .Include(b => b.WorkerAssignments).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.User)
        // Needed to say whether each worker can actually be paid, before a pay run is started.
        .Include(b => b.WorkerAssignments).ThenInclude(a => a.WorkerProfile).ThenInclude(wp => wp.PayoutDetail)
        .Include(b => b.Address)
        // What the customer told the business about the job. Loaded on every read because it is
        // what the business staffs from, and a handful of short rows per order.
        .Include(b => b.ServiceAnswers)
        .Include(b => b.AgreementProposals)
        .Include(b => b.Rating);

    public Task<Booking?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        IncludeGraph(dbContext.Bookings).FirstOrDefaultAsync(b => b.Id == id, cancellationToken);

    public async Task<List<Booking>> GetByCustomerIdAsync(Guid customerProfileId, CancellationToken cancellationToken) =>
        await IncludeGraph(dbContext.Bookings)
            .Where(b => b.CustomerProfileId == customerProfileId)
            .OrderByDescending(b => b.CreatedDate)
            .ToListAsync(cancellationToken);

    public async Task<List<Booking>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken) =>
        await IncludeGraph(dbContext.Bookings)
            .Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId)
            .OrderByDescending(b => b.CreatedDate)
            .ToListAsync(cancellationToken);

    public async Task<List<Booking>> GetByWorkerIdAsync(Guid workerProfileId, CancellationToken cancellationToken) =>
        await IncludeGraph(dbContext.Bookings)
            .Where(b => b.WorkerAssignments.Any(a => a.WorkerProfileId == workerProfileId))
            .OrderByDescending(b => b.CreatedDate)
            .ToListAsync(cancellationToken);

    public async Task<List<Booking>> GetByBusinessAndCategoriesAsync(
        Guid businessOwnerProfileId,
        IReadOnlyCollection<Guid> serviceCategoryIds,
        CancellationToken cancellationToken) =>
        await IncludeGraph(dbContext.Bookings)
            .Where(b => b.BusinessOwnerProfileId == businessOwnerProfileId
                && serviceCategoryIds.Contains(b.BusinessService.ServiceCategoryId))
            .OrderByDescending(b => b.CreatedDate)
            .ToListAsync(cancellationToken);

    public void Add(Booking booking) => dbContext.Bookings.Add(booking);
}
