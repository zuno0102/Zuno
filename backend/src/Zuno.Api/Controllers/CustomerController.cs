using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Customer.Queries.GetBusinessDetail;
using Zuno.Application.Modules.Customer.Queries.SearchBusinesses;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/customer/businesses")]
[Authorize(Policy = AuthorizationPolicyNames.RequireCustomerRole)]
public class CustomerController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Search(
        [FromQuery] Guid? categoryId,
        [FromQuery] string? keyword,
        [FromQuery] List<Guid>? districtIds,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SearchBusinessesQuery { ServiceCategoryId = categoryId, Keyword = keyword, DistrictIds = districtIds },
            cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetDetail(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBusinessDetailQuery { BusinessId = id }, cancellationToken);
        return Ok(result);
    }
}
