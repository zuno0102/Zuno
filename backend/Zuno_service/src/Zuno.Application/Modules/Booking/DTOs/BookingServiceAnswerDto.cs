using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Booking.DTOs;

/// <summary>One thing the customer told the business when placing the order.</summary>
public class BookingServiceAnswerDto
{
    public Guid Id { get; set; }

    /// <summary>The question as it was worded at the time, not as it reads today.</summary>
    public string QuestionPrompt { get; set; } = string.Empty;

    public string AnswerText { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}

public static class BookingServiceAnswerMappingExtensions
{
    public static BookingServiceAnswerDto ToDto(this BookingServiceAnswer answer) => new()
    {
        Id = answer.Id,
        QuestionPrompt = answer.QuestionPrompt,
        AnswerText = answer.AnswerText,
        SortOrder = answer.SortOrder,
    };

    /// <summary>
    /// The answers in the order they were asked, taken from the answers themselves.
    /// </summary>
    /// <remarks>
    /// Ordered by the answer's own recorded position, never by the live question's: a business
    /// dragging its questions around today must not reshuffle orders taken last year.
    /// </remarks>
    public static List<BookingServiceAnswerDto> ToAnswerDtos(
        this IEnumerable<BookingServiceAnswer> answers) =>
        [.. answers
            .OrderBy(a => a.SortOrder)
            .ThenBy(a => a.CreatedDate)
            .Select(a => a.ToDto())];
}
