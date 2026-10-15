using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// What an order's crew is owed, gathered from the hiring posts raised against it.
/// </summary>
/// <remarks>
/// A service rather than a property on the booking. The posts are not part of the graph any booking
/// read loads, and an unloaded collection would answer "nobody is owed anything" — confidently, and
/// wrongly, on a screen about money.
/// </remarks>
public interface IBookingWageService
{
    Task<BookingWageRollup> GetAsync(Guid bookingId, CancellationToken cancellationToken = default);

    /// <summary>
    /// The same figures for a list of orders in one round trip. Orders owing nothing are absent
    /// from the result; read them as <see cref="BookingWageRollup.None"/>.
    /// </summary>
    Task<IReadOnlyDictionary<Guid, BookingWageRollup>> GetManyAsync(
        IReadOnlyCollection<Guid> bookingIds,
        CancellationToken cancellationToken = default);
}
