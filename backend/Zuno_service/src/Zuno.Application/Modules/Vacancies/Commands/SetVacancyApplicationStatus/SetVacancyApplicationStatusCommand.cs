using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Commands.SetVacancyApplicationStatus;

/// <summary>
/// The business records where it has got to with an applicant. Hiring happens outside the app; this
/// is its notebook, and the worker's way of hearing back.
/// </summary>
public class SetVacancyApplicationStatusCommand : IRequest<VacancyApplicationDto>
{
    [JsonIgnore]
    public Guid ApplicationId { get; set; }

    /// <summary>Shortlisted, Hired or Rejected. Omitted, only the note is saved.</summary>
    public VacancyApplicationStatus? Status { get; set; }

    /// <summary>Private to the business. Omitted, the existing note is kept.</summary>
    public string? Note { get; set; }
}
