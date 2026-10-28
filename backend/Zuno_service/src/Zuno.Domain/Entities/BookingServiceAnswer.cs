using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// What the customer told the business about this job, in answer to one of its questions.
/// </summary>
/// <remarks>
/// The question's wording is <b>copied here</b>, not looked up. A business is free to reword,
/// reorder or retire a question at any time, and none of that may change what an order placed
/// months ago says it was told. The same discipline the price already follows: <c>PriceQuoted</c>
/// snapshots the service price rather than reading it live.
///
/// Because of that, nothing on the read path joins back to <see cref="BusinessServiceQuestion"/>.
/// It would also be wrong to: questions are soft-deleted behind a global filter, so a join would
/// silently drop the answers belonging to retired questions. <see cref="BusinessServiceQuestionId"/>
/// is a back-pointer for reporting, never a source of display text.
/// </remarks>
public class BookingServiceAnswer : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    /// <summary>Which question this answered, for reporting. Never read to render the answer.</summary>
    public Guid? BusinessServiceQuestionId { get; set; }

    /// <summary>The question as it was worded when the customer answered it.</summary>
    public string QuestionPrompt { get; set; } = string.Empty;

    /// <summary>The customer's answer.</summary>
    public string AnswerText { get; set; } = string.Empty;

    /// <summary>Where it sat in the list at the time. Read answers by this, never by the live question's.</summary>
    public short SortOrder { get; set; }
}
