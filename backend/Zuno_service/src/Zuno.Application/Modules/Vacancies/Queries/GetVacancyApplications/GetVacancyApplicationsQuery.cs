using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyApplications;

/// <summary>Who applied to one of the business's vacancies — or to any of them — newest first.</summary>
public class GetVacancyApplicationsQuery : IRequest<VacancyPageDto<VacancyApplicationDto>>
{
    /// <summary>One vacancy. Omitted, every vacancy the business owns — the home screen's tiles.</summary>
    public Guid? VacancyId { get; set; }

    /// <summary>One list — New (Applied), Waiting (Viewed), Shortlisted or Hired. Omitted, all but the rejected.</summary>
    public VacancyApplicationStatus? Status { get; set; }

    public int? Take { get; set; }

    public DateTimeOffset? Before { get; set; }
}
