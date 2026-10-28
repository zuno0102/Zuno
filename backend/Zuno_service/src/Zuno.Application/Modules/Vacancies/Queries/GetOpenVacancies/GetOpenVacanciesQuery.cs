using MediatR;
using Zuno.Application.Modules.Vacancies.DTOs;

namespace Zuno.Application.Modules.Vacancies.Queries.GetOpenVacancies;

/// <summary>
/// Live vacancies for a worker, newest first, optionally near them. Every filter is optional, so the
/// feed works for a worker who has not shared a location.
/// </summary>
public class GetOpenVacanciesQuery : IRequest<VacancyPageDto<VacancyDto>>
{
    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>Drops vacancies further than this. Ignored without a position.</summary>
    public double? RadiusKm { get; set; }

    public Guid? JobTypeId { get; set; }

    public List<Guid>? DistrictIds { get; set; }

    public int? Take { get; set; }

    /// <summary>The previous page's <c>NextBefore</c>.</summary>
    public DateTimeOffset? Before { get; set; }
}
