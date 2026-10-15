using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IBookingRepository
{
    Task<Booking?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    Task<List<Booking>> GetByCustomerIdAsync(Guid customerProfileId, CancellationToken cancellationToken);

    Task<List<Booking>> GetByBusinessIdAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken);

    Task<List<Booking>> GetByWorkerIdAsync(Guid workerProfileId, CancellationToken cancellationToken);

    /// <summary>A business's orders in some of its categories — what a supervisor or manager sees.</summary>
    Task<List<Booking>> GetByBusinessAndCategoriesAsync(
        Guid businessOwnerProfileId,
        IReadOnlyCollection<Guid> serviceCategoryIds,
        CancellationToken cancellationToken);

    void Add(Booking booking);
}
