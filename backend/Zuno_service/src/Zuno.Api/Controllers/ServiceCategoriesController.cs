using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Application.Modules.Catalog.Queries.GetServiceCategories;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/service-categories")]
[AllowAnonymous]
public class ServiceCategoriesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetServiceCategoriesQuery(), cancellationToken);
        return Ok(result);
    }
}
