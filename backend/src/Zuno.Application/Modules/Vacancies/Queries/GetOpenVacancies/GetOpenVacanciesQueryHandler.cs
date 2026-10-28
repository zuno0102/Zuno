using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Vacancies.Common;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Vacancies.Queries.GetOpenVacancies;

public class GetOpenVacanciesQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IOptions<VacancySettings> settings,
    IApplicationDbContext dbContext) : IRequestHandler<GetOpenVacanciesQuery, VacancyPageDto<VacancyDto>>
{
    public async Task<VacancyPageDto<VacancyDto>> Handle(GetOpenVacanciesQuery request, CancellationToken cancellationToken)
    {
        var workerProfileId = await VacancyActor.WorkerProfileIdAsync(currentUserService, dbContext, cancellationToken);
        var now = dateTimeProvider.UtcNow;
        var take = settings.Value.PageSize(request.Take);
        var hasPosition = request is { Latitude: not null, Longitude: not null };

        var query = dbContext.Vacancies
            .AsNoTracking()
            .Where(Vacancy.LiveAt(now));

        if (request.JobTypeId is { } jobTypeId)
        {
            query = query.Where(v => v.VacancyJobTypeId == jobTypeId);
        }

        if (request.DistrictIds is { Count: > 0 } districtIds)
        {
            query = query.Where(v => v.DistrictId != null && districtIds.Contains(v.DistrictId.Value));
        }

        if (hasPosition && request.RadiusKm is { } radiusKm)
        {
            // Four plain comparisons, so the cut happens in SQL. The square over-selects its circle's
            // corners; the true distance trims those below.
            var box = GeoDistance.BoundingBox(request.Latitude!.Value, request.Longitude!.Value, radiusKm);
            query = query.Where(v =>
                v.Latitude >= box.MinLatitude && v.Latitude <= box.MaxLatitude
                && v.Longitude >= box.MinLongitude && v.Longitude <= box.MaxLongitude);
        }

        if (request.Before is { } before)
        {
            query = query.Where(v => v.PublishedAt < before);
        }

        var page = await query
            .OrderByDescending(v => v.PublishedAt)
            .Take(take)
            .Select(VacancyProjections.ToDto(workerProfileId, now))
            .ToListAsync(cancellationToken);

        // The cursor follows the rows the database returned, not the ones kept, so trimming a corner
        // can shorten a page but never skip or repeat a vacancy on the next one.
        var nextBefore = page.Count == take ? page[^1].PublishedAt : null;

        if (hasPosition)
        {
            foreach (var dto in page.Where(d => d.Latitude.HasValue && d.Longitude.HasValue))
            {
                dto.DistanceKm = Math.Round(
                    GeoDistance.HaversineKm(
                        request.Latitude!.Value, request.Longitude!.Value, (double)dto.Latitude!.Value, (double)dto.Longitude!.Value),
                    1);
            }

            if (request.RadiusKm is { } radius)
            {
                page = page.Where(d => d.DistanceKm <= radius).ToList();
            }
        }

        return new VacancyPageDto<VacancyDto> { Items = page, NextBefore = nextBefore };
    }
}
