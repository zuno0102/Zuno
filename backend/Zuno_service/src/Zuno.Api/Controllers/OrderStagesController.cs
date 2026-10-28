using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetOrderStages;

namespace Zuno.Api.Controllers;

/// <summary>
/// The names, colours and order of order stages, for the apps' status chips and filters. Signed-in
/// users only: nobody else sees an order.
/// </summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/order-stages")]
public class OrderStagesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetOrderStagesQuery(), cancellationToken);
        return Ok(result);
    }
}
