using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Business.DTOs;

/// <summary>
/// One box the business wants the customer to fill in when booking.
/// </summary>
/// <remarks>
/// Sent to the business so it can edit its own list, and to the customer so the booking form can
/// be drawn from it. The same shape serves both: there is nothing private about a question.
/// </remarks>
public class ServiceQuestionDto
{
    public Guid Id { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }

    public short SortOrder { get; set; }
}

public static class ServiceQuestionMappingExtensions
{
    public static ServiceQuestionDto ToDto(this BusinessServiceQuestion question) => new()
    {
        Id = question.Id,
        Prompt = question.Prompt,
        IsRequired = question.IsRequired,
        SortOrder = question.SortOrder,
    };

    /// <summary>A service's questions, in the order the business arranged them.</summary>
    public static List<ServiceQuestionDto> ToQuestionDtos(this IEnumerable<BusinessServiceQuestion> questions) =>
        [.. questions.OrderBy(q => q.SortOrder).Select(q => q.ToDto())];
}
