using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// One party clearing a booking's conversation from their own list.
/// </summary>
/// <remarks>
/// Per person, and never destructive. A customer tidying their chat list must not be able to erase
/// what a business was told — the thread is where an address or a time was agreed, and either side
/// may need it later. So clearing records a point in time for that user: everything up to it stops
/// being shown to them, while the other side's copy is untouched.
///
/// It also means a thread comes back if the other side writes again, which is what somebody expects:
/// clearing says "I am done with this", not "never speak to me about this order".
/// </remarks>
public class BookingThreadClear : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    /// <summary>Whose list it was cleared from.</summary>
    public Guid UserId { get; set; }

    /// <summary>Messages at or before this are hidden from that user.</summary>
    public DateTimeOffset ClearedAt { get; set; }
}
