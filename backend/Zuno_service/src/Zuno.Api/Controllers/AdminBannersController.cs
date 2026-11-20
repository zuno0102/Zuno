using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Admin.Commands.SetServiceBanner;

namespace Zuno.Api.Controllers;

/// <summary>Paid banners: which services are in the customers' top banner, and until when.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/admin/banners")]
[Authorize(Policy = AuthorizationPolicyNames.RequireSuperAdminRole)]
public class AdminBannersController(ISender mediator) : ControllerBase
{
    /// <summary>Records a paid banner for a service until <c>paidUntil</c>; an empty date ends it.</summary>
    [HttpPut("services/{id:guid}")]
    public async Task<IActionResult> SetServiceBanner(Guid id, [FromBody] BannerRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new SetServiceBannerCommand(id, request.PaidUntil), cancellationToken));

    public record BannerRequest(DateTimeOffset? PaidUntil);
}
