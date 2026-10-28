using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyOptions;

/// <summary>The active job types, documents and fee plans the vacancy forms offer.</summary>
public record GetVacancyOptionsQuery : IRequest<VacancyOptionsDto>;
