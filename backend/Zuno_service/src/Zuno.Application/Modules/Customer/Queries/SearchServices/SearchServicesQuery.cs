using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.SearchServices;

/// <summary>
/// Browses services across every business, which is how a customer actually looks for one.
/// </summary>
/// <param name="CategoryId">Narrows to a single category. Null browses everything.</param>
/// <param name="Keyword">Matched against the service name and the business name.</param>
public record SearchServicesQuery(
    Guid? CategoryId = null,
    string? Keyword = null,
    List<Guid>? DistrictIds = null,
    int Take = 40) : IRequest<List<ServiceListingDto>>;
