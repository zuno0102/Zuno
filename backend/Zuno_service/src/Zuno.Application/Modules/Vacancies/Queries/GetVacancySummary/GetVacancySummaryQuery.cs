using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancySummary;

/// <summary>Counts for the business home screen: live posts, and applicants by list.</summary>
public record GetVacancySummaryQuery : IRequest<VacancySummaryDto>;
