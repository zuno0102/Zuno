using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetDistricts;

public class GetDistrictsQuery : IRequest<List<DistrictDto>>
{
    public List<Guid>? StateIds { get; set; }
}
