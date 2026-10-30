using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Application.Categories;

namespace Zuno.Rent.Api.Controllers;

/// <summary>How a rent item can be charged — per day, per item, per hour. Any signed-in user.</summary>
[ApiController]
[Route("api/v1/rental-price-types")]
public class RentalPriceTypesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalPriceTypesQuery(), cancellationToken));
}
