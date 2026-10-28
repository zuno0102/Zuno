namespace Zuno.Application.Modules.Booking.DTOs;

/// <summary>One message in a booking's thread.</summary>
public class BookingMessageDto
{
    public Guid Id { get; set; }

    public Guid BookingId { get; set; }

    /// <summary>`Customer` or `Business` — which side wrote it.</summary>
    public string SenderRole { get; set; } = string.Empty;

    /// <summary>
    /// Whether the person reading this is the one who sent it.
    /// </summary>
    /// <remarks>
    /// Worked out here rather than in the app. The client would otherwise need to know which role it
    /// is signed in as to decide which side of the screen a bubble belongs on, and the two have
    /// already disagreed once in this codebase about who "my" means.
    /// </remarks>
    public bool IsMine { get; set; }

    public string SenderName { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public DateTimeOffset SentAt { get; set; }

    /// <summary>When the other side read it. Null while unread, and only meaningful on your own.</summary>
    public DateTimeOffset? ReadAt { get; set; }
}

/// <summary>A booking that has a conversation on it, as the chat list shows it.</summary>
public class BookingThreadDto
{
    public Guid BookingId { get; set; }

    /// <summary>What the order is for — the variant where there is one, otherwise the service.</summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>Who the other side is: the business to a customer, the customer to a business.</summary>
    public string CounterpartName { get; set; } = string.Empty;

    public string? CounterpartLogoUrl { get; set; }

    public DateTimeOffset ScheduledDate { get; set; }

    public string BookingStatus { get; set; } = string.Empty;

    /// <summary>The most recent message, for the preview line. Null on a thread nobody has opened.</summary>
    public string? LastMessage { get; set; }

    public DateTimeOffset? LastMessageAt { get; set; }

    /// <summary>Whether the last message is one you sent, so the preview can say "You: ...".</summary>
    public bool LastMessageIsMine { get; set; }

    /// <summary>Messages from the other side you have not read.</summary>
    public int UnreadCount { get; set; }
}
