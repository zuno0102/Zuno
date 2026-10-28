using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;

/// <summary>One box the business wants the customer to fill in.</summary>
public class ServiceQuestionInput
{
    /// <summary>Null for a new question; otherwise the one being edited, kept so answers stay linked.</summary>
    public Guid? Id { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }
}

/// <summary>
/// Replaces a service's whole question set, in the order given.
/// </summary>
/// <remarks>
/// One command rather than add/edit/delete/reorder: the business edits these as a list on a form
/// and saves once, so four endpoints would mean four round-trips and a half-saved set if one of
/// them failed.
///
/// Questions dropped from the list are soft-deleted, which takes them off the booking form while
/// leaving every answer already given to them untouched — each answer carries its own copy of the
/// wording.
/// </remarks>
public class SetBusinessServiceQuestionsCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    /// <summary>The complete set, in display order. An empty list clears them.</summary>
    public List<ServiceQuestionInput> Questions { get; set; } = [];
}
