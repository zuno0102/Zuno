namespace Zuno.Application.Modules.WorkChat.DTOs;

/// <summary>One message in a business–worker conversation, as the reader sees it.</summary>
public class WorkMessageDto
{
    public Guid Id { get; set; }

    /// <summary>The other side's profile id — the id the reader opens this conversation with.</summary>
    public Guid CounterpartId { get; set; }

    /// <summary>"Business" or "Worker".</summary>
    public string SenderRole { get; set; } = string.Empty;

    /// <summary>Whether the reader sent it. Worked out on the server, as for booking messages.</summary>
    public bool IsMine { get; set; }

    public string SenderName { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public DateTimeOffset SentAt { get; set; }

    public DateTimeOffset? ReadAt { get; set; }
}

/// <summary>One business–worker conversation in the reader's list.</summary>
public class WorkThreadDto
{
    /// <summary>The other side's profile id: a worker for a business, a business for a worker.</summary>
    public Guid CounterpartId { get; set; }

    public string CounterpartName { get; set; } = string.Empty;

    /// <summary>The business's logo or the worker's photo, when there is one.</summary>
    public string? CounterpartImageUrl { get; set; }

    public string LastMessage { get; set; } = string.Empty;

    public DateTimeOffset LastMessageAt { get; set; }

    public bool LastMessageIsMine { get; set; }

    public int UnreadCount { get; set; }
}
