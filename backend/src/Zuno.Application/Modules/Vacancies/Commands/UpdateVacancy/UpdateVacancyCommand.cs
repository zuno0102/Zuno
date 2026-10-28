using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.UpdateVacancy;

/// <summary>Edits a vacancy in any state. Its status and paid period are not touched here.</summary>
public class UpdateVacancyCommand : VacancyFieldsCommand, IRequest<VacancyDto>
{
    /// <summary>From the route, never the body.</summary>
    [JsonIgnore]
    public Guid VacancyId { get; set; }
}
