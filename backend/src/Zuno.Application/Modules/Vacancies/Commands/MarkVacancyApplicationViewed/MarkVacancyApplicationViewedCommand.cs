using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.MarkVacancyApplicationViewed;

/// <summary>
/// The business opened an applicant. A new application moves to Waiting and the worker sees
/// "Application viewed"; opening it again, or one already decided, changes nothing.
/// </summary>
public record MarkVacancyApplicationViewedCommand(Guid ApplicationId) : IRequest<VacancyApplicationDto>;
