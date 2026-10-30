using MediatR;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Application.Orders;

namespace Zuno.Rent.Api.Controllers;

/// <summary>How an advance can be asked and how money can be taken — the words for the forms. Any signed-in user.</summary>
[ApiController]
[Route("api/v1/rental-payment-options")]
public class RentalPaymentOptionsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetRentalPaymentOptionsQuery(), cancellationToken));
}
