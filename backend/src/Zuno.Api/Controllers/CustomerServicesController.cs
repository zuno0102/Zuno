using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Customer.Queries.GetDailyBanners;
using Zuno.Application.Modules.Customer.Queries.GetHomeSections;
using Zuno.Application.Modules.Customer.Queries.GetServiceDetail;
using Zuno.Application.Modules.Customer.Queries.SearchServices;

namespace Zuno.Api.Controllers;

/// <summary>
/// Browsing services across every business, rather than one business at a time.
/// </summary>
/// <remarks>
/// Its own controller because it is a different question from "show me this business". A
/// customer starts from what they need — catering, a photographer — and only then cares whose
/// it is.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/customer/services")]
[Authorize(Policy = AuthorizationPolicyNames.RequireCustomerRole)]
public class CustomerServicesController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Search(
        [FromQuery] Guid? categoryId,
        [FromQuery] string? keyword,
        [FromQuery] List<Guid>? districtIds,
        [FromQuery] int take = 40,
        CancellationToken cancellationToken = default)
    {
        var result = await mediator.Send(
            new SearchServicesQuery(categoryId, keyword, districtIds, take),
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Every section of the customer home screen, composed so none of them repeat.</summary>
    [HttpGet("home")]
    public async Task<IActionResult> GetHome(
        [FromQuery] int? seed,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetHomeSectionsQuery(seed), cancellationToken);
        return Ok(result);
    }

    /// <summary>Today's banner services — seven, and a different seven tomorrow.</summary>
    /// <remarks>
    /// Declared before the <c>{id:guid}</c> route for readability only; "banners" is not a guid, so
    /// the two could not collide in any case.
    /// </remarks>
    [HttpGet("banners")]
    public async Task<IActionResult> GetBanners(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetDailyBannersQuery(), cancellationToken);
        return Ok(result);
    }

    /// <summary>One service on its own, with every package it is sold in.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetDetail(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetServiceDetailQuery(id), cancellationToken);
        return Ok(result);
    }
}
