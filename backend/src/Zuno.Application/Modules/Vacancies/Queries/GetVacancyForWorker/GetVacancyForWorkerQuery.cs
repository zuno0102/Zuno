using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyForWorker;

/// <summary>One vacancy for a worker: a live one, or any they have applied to.</summary>
public record GetVacancyForWorkerQuery(Guid VacancyId) : IRequest<VacancyDto>;
