using FluentValidation;
using MediatR;

namespace Zuno.Application.Modules.Catalog.Queries.GetNearestDistrict;

/// <summary>
/// Which district a point is in — for the customer app, which reads the phone's location when it
/// opens and narrows every listing (Service, Rent) to that district.
/// </summary>
public record GetNearestDistrictQuery(decimal Latitude, decimal Longitude) : IRequest<NearestDistrictDto?>;

/// <summary>The district, or null when the point is too far from every district Zuno knows.</summary>
public record NearestDistrictDto(Guid DistrictId, string DistrictName, Guid StateId, string StateName, double DistanceKm);

public class GetNearestDistrictQueryValidator : AbstractValidator<GetNearestDistrictQuery>
{
    public GetNearestDistrictQueryValidator()
    {
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
    }
}
