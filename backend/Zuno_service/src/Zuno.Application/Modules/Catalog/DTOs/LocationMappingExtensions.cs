using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Catalog.DTOs;

public static class LocationMappingExtensions
{
    public static StateDto ToDto(this State state) => new()
    {
        Id = state.Id,
        Name = state.Name,
    };

    public static DistrictDto ToDto(this District district) => new()
    {
        Id = district.Id,
        Name = district.Name,
        StateId = district.StateId,
        StateName = district.State.Name,
        CentreLatitude = district.CentreLatitude,
        CentreLongitude = district.CentreLongitude,
    };
}
