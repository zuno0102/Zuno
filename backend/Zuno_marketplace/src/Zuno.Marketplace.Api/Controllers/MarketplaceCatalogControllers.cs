using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Marketplace.Api.Common;
using Zuno.Marketplace.Application.Admin;
using Zuno.Marketplace.Application.Categories;

namespace Zuno.Marketplace.Api.Controllers;

/// <summary>The lists the Marketplace screens are drawn from. Any signed-in user.</summary>
[ApiController]
[Route("api/v1")]
public class MarketplaceCatalogController(ISender mediator) : ControllerBase
{
    /// <summary>The active categories, each with the details it asks for.</summary>
    [HttpGet("marketplace-categories")]
    public async Task<IActionResult> GetCategories(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMarketplaceCategoriesQuery(), cancellationToken));

    /// <summary>Post kinds, statuses (with colours) and the limits the post form checks against.</summary>
    [HttpGet("marketplace-options")]
    public async Task<IActionResult> GetOptions(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMarketplaceOptionsQuery(), cancellationToken));
}

/// <summary>The super admin's Marketplace categories and their details.</summary>
[ApiController]
[Route("api/v1/admin/marketplace/categories")]
[Authorize(Policy = MarketplacePolicies.SuperAdmin)]
public class AdminMarketplaceCategoriesController(ISender mediator) : ControllerBase
{
    /// <summary>Every category, switched off or not, with every detail.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMarketplaceCategoriesQuery(IncludeInactive: true), cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateMarketplaceCategoryCommand command, CancellationToken cancellationToken) =>
        StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateMarketplaceCategoryCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPost("{categoryId:guid}/sub-categories")]
    public async Task<IActionResult> CreateSubCategory(
        Guid categoryId, [FromBody] CreateMarketplaceSubCategoryCommand command, CancellationToken cancellationToken)
    {
        command.CategoryId = categoryId;
        return StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
    }

    [HttpPut("{categoryId:guid}/sub-categories/{id:guid}")]
    public async Task<IActionResult> UpdateSubCategory(
        Guid categoryId, Guid id, [FromBody] UpdateMarketplaceSubCategoryCommand command, CancellationToken cancellationToken)
    {
        command.CategoryId = categoryId;
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }

    [HttpPost("{categoryId:guid}/fields")]
    public async Task<IActionResult> CreateField(
        Guid categoryId, [FromBody] CreateMarketplaceFieldCommand command, CancellationToken cancellationToken)
    {
        command.CategoryId = categoryId;
        return StatusCode(StatusCodes.Status201Created, await mediator.Send(command, cancellationToken));
    }

    [HttpPut("{categoryId:guid}/fields/{id:guid}")]
    public async Task<IActionResult> UpdateField(
        Guid categoryId, Guid id, [FromBody] UpdateMarketplaceFieldCommand command, CancellationToken cancellationToken)
    {
        command.CategoryId = categoryId;
        command.Id = id;
        return Ok(await mediator.Send(command, cancellationToken));
    }
}
