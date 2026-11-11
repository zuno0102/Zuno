using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Customer.Location;

namespace Zuno.Api.Controllers;

/// <summary>The customer's own location — the district every listing is narrowed to.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/customer/location")]
[Authorize(Policy = AuthorizationPolicyNames.RequireCustomerRole)]
public class CustomerLocationController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyCustomerLocationQuery(), cancellationToken));

    [HttpPut]
    public async Task<IActionResult> Set([FromBody] SetMyCustomerLocationCommand command, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(command, cancellationToken));
}
