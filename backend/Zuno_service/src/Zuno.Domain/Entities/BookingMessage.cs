using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// One message between the customer and the business about a booking.
/// </summary>
/// <remarks>
/// Attached to the booking rather than to the pair of people, which is the decision the rest of this
/// feature rests on. A customer who books the same caterer three times is having three different
/// conversations — "what time are you arriving?" means nothing without knowing which day — and a
/// single thread per business would mix them and leave both sides scrolling to work out which job a
/// message was about. The booking is already the thing both sides are looking at.
///
/// It also settles who may speak: exactly two parties, the customer on the order and the business
/// that owns it, and both are already recorded on the booking. No membership table, and no way to
/// end up with a thread nobody is allowed to read.
///
/// Phone calls are not replaced. A booking still carries the business's number, and this is for the
/// things worth having in writing — an address, a time, what was agreed.
/// </remarks>
public class BookingMessage : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    /// <summary>Which side sent it.</summary>
    /// <remarks>
    /// Stored rather than worked out from <see cref="SenderUserId"/> at read time. A business can
    /// change hands and a profile's user can change with it; what was said and by which side cannot.
    /// </remarks>
    public BookingPartyRole SenderRole { get; set; }

    public Guid SenderUserId { get; set; }

    public string Body { get; set; } = string.Empty;

    /// <summary>
    /// When the other side read it, or null while it is still unread.
    /// </summary>
    /// <remarks>
    /// One timestamp is enough because there are only ever two parties: a message is read, or it is
    /// not, by the one person who did not send it. The sender's own messages are never counted as
    /// unread for them.
    /// </remarks>
    public DateTimeOffset? ReadAt { get; set; }

    public bool IsUnread => ReadAt is null;
}
