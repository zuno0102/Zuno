using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Commands.SetVacancyHiring;

/// <summary>
/// Stops hiring (hides the vacancy, keeps everything) or starts it again. Starting again needs no
/// payment while the paid period lasts.
/// </summary>
public record SetVacancyHiringCommand(Guid VacancyId, bool IsHiring) : IRequest<VacancyDto>;
