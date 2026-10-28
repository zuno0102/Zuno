using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetMyVacancyApplications;

/// <summary>The vacancies the worker has applied to, most recent application first.</summary>
public class GetMyVacancyApplicationsQuery : IRequest<VacancyPageDto<VacancyDto>>
{
    public int? Take { get; set; }

    /// <summary>The previous page's <c>NextBefore</c> — an application time.</summary>
    public DateTimeOffset? Before { get; set; }
}
