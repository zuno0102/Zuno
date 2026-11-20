using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application.Items;

namespace Zuno.Rent.Api.Controllers;

/// <summary>Paid banners: which rent items are in the customers' top banner, and until when.</summary>
[ApiController]
[Route("api/v1/admin/banners/rentals")]
[Authorize(Policy = RentPolicies.SuperAdmin)]
public class AdminRentalBannersController(ISender mediator) : ControllerBase
{
    /// <summary>Records a paid banner for an item until <c>paidUntil</c>; an empty date ends it.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Set(Guid id, [FromBody] SetRentalBannerCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }
}
