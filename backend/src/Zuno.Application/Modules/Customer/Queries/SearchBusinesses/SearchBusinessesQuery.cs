using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.SearchBusinesses;

public class SearchBusinessesQuery : IRequest<List<BusinessSummaryDto>>
{
    public Guid? ServiceCategoryId { get; set; }

    public string? Keyword { get; set; }

    public List<Guid>? DistrictIds { get; set; }
}
