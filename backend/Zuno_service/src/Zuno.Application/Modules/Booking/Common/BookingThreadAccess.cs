using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Common;

/// <summary>Who the signed-in user is on a particular booking.</summary>
/// <param name="Role">Which side they are.</param>
/// <param name="UserId">Their user id, which is what a sent message is stamped with.</param>
/// <param name="DisplayName">What the other side should see as the sender.</param>
/// <param name="CounterpartUserId">
/// The other party on the order — who a sent message is addressed to.
/// </param>
/// <param name="BookingStatus">Where the order stands.</param>
/// <param name="HasRating">Whether the customer has rated it, which closes the conversation.</param>
public readonly record struct BookingParticipant(
    BookingPartyRole Role,
    Guid UserId,
    string DisplayName,
    Guid CounterpartUserId,
    BookingStatus BookingStatus,
    bool HasRating);

/// <summary>
/// Settles who is allowed to read or write a booking's thread.
/// </summary>
/// <remarks>
/// One place, used by every message handler, because this is the whole access rule for the feature:
/// a booking's conversation is open to exactly two people — the customer who placed it and the owner
/// of the business that holds it — and to nobody else. Spread across three handlers it would be
/// three chances to get it wrong, and the thing it protects is private correspondence including
/// addresses and times.
///
/// Anyone else asking is refused outright rather than shown an empty thread: an empty thread says the
/// booking exists, and that is already more than a stranger should learn from a guessed id.
/// </remarks>
public static class BookingThreadAccess
{
    /// <summary>
    /// The states an order can be written on: confirmed and onwards, and never once called off.
    /// </summary>
    /// <remarks>
    /// The same window as the phone number on a booking, and deliberately the same rule rather than a
    /// second one that could drift from it. Before a business has taken the order on there is nothing
    /// agreed to discuss, and once it is cancelled there is nothing left to arrange.
    ///
    /// An inclusion list rather than "not pending and not cancelled": a state added later is left out
    /// until somebody decides it belongs, which is the safe direction for a rule guarding private
    /// correspondence.
    /// </remarks>
    private static readonly BookingStatus[] Messageable =
    [
        BookingStatus.Confirmed,
        BookingStatus.Assigned,
        BookingStatus.InProgress,
        BookingStatus.Completed,
    ];

    /// <summary>
    /// Whether this order can still be written on.
    /// </summary>
    /// <param name="status">Where the order stands.</param>
    /// <param name="hasRating">
    /// Whether the customer has rated it. Rating is the customer's last act on an order — it is
    /// offered only once and cannot be taken back — so it closes the conversation with it. A finished
    /// job stays open to messages until then, which is the window where a missing item or an invoice
    /// actually gets sorted out.
    /// </param>
    public static bool CanMessage(BookingStatus status, bool hasRating) =>
        Messageable.Contains(status)
        && !(status == BookingStatus.Completed && hasRating);

    public static async Task<BookingParticipant> ResolveAsync(
        IApplicationDbContext dbContext,
        Guid bookingId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var booking = await dbContext.Bookings
            .Where(b => b.Id == bookingId)
            .Select(b => new
            {
                CustomerUserId = b.CustomerProfile.UserId,
                CustomerName = b.CustomerProfile.User.FirstName + " " + b.CustomerProfile.User.LastName,
                BusinessUserId = b.BusinessOwnerProfile.UserId,
                BusinessName = b.BusinessOwnerProfile.BusinessName,
                b.BookingStatus,
                HasRating = b.Rating != null,
            })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), bookingId);

        if (booking.CustomerUserId == userId)
        {
            return new BookingParticipant(
                BookingPartyRole.Customer,
                userId,
                booking.CustomerName.Trim(),
                booking.BusinessUserId,
                booking.BookingStatus,
                booking.HasRating);
        }

        if (booking.BusinessUserId == userId)
        {
            return new BookingParticipant(
                BookingPartyRole.Business,
                userId,
                booking.BusinessName,
                booking.CustomerUserId,
                booking.BookingStatus,
                booking.HasRating);
        }

        throw new UnauthorizedAccessException(
            "This conversation belongs to the customer and the business on the order.");
    }
}
