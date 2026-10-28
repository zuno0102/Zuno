using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetMyVacancies;

/// <summary>The business's own vacancies in every state, newest first.</summary>
public class GetMyVacanciesQuery : IRequest<VacancyPageDto<VacancyDto>>
{
    public int? Take { get; set; }

    /// <summary>The previous page's <c>NextBefore</c>.</summary>
    public DateTimeOffset? Before { get; set; }
}
