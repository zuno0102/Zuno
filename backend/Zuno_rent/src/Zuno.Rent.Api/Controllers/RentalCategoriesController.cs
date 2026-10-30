using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Application.Categories;

namespace Zuno.Rent.Api.Controllers;

/// <summary>The rent catalogue — categories with their sub-categories. Any signed-in user.</summary>
[ApiController]
[Route("api/v1/rental-categories")]
public class RentalCategoriesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalCategoriesQuery(), cancellationToken));
}
