using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Catalog.Commands.SaveServiceCategory;
using Zuno.Application.Modules.Catalog.Commands.SaveServiceSubCategory;
using Zuno.Application.Modules.Catalog.Commands.SetServiceCategoryIcon;
using Zuno.Application.Modules.Catalog.Queries.GetCatalogForAdmin;

namespace Zuno.Api.Controllers;

/// <summary>
/// The kinds of work the product offers, managed by the app owner.
/// </summary>
/// <remarks>
/// Until these existed, the catalogue could only grow by hand-writing a migration — which is how
/// "Acrylic painting" was added, and why a business could not list catering work at all. The point
/// of these endpoints is that any new kind of work can be added without a developer.
///
/// Nothing here deletes. Businesses price real services against these rows, so retiring one means
/// hiding it: it leaves the pickers and every existing service carries on unchanged.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/admin/catalog")]
[Authorize(Policy = AuthorizationPolicyNames.RequireSuperAdminRole)]
public class AdminCatalogController(
    ISender mediator,
    IFileStorageService fileStorageService,
    IOptions<FileStorageSettings> fileStorageSettings) : ControllerBase
{
    /// <summary>Icon formats the apps can render. SVG is left out: Flutter cannot draw one unaided.</summary>
    private static readonly HashSet<string> AllowedIconContentTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "image/png",
            "image/webp",
            "image/jpeg",
        };

    /// <summary>The whole catalogue, hidden rows included.</summary>
    [HttpGet("categories")]
    public async Task<IActionResult> GetCatalog(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetCatalogForAdminQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("categories")]
    public async Task<IActionResult> CreateCategory(
        SaveServiceCategoryCommand command,
        CancellationToken cancellationToken)
    {
        // The route says "new", so the body cannot say otherwise. Without this, a POST carrying an
        // Id would quietly edit an existing category instead of adding one.
        command.Id = null;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPut("categories/{id:guid}")]
    public async Task<IActionResult> UpdateCategory(
        Guid id,
        SaveServiceCategoryCommand command,
        CancellationToken cancellationToken)
    {
        command.Id = id;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Uploads or replaces a category's icon.</summary>
    /// <remarks>
    /// The point of this endpoint: the apps can only draw icons compiled into them, so a new category
    /// wanting artwork outside that set would otherwise wait for a release. An uploaded image is shown
    /// in preference to the built-in one, which makes adding a category entirely self-service.
    /// </remarks>
    [HttpPut("categories/{id:guid}/icon")]
    public async Task<IActionResult> SetCategoryIcon(
        Guid id,
        IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            return BadRequest(ApiResponse.Fail("No file was uploaded.", HttpContext.TraceIdentifier));
        }

        if (file.Length > fileStorageSettings.Value.MaxFileSizeBytes)
        {
            return BadRequest(ApiResponse.Fail(
                $"Icon must be {fileStorageSettings.Value.MaxFileSizeBytes / (1024 * 1024)}MB or smaller.",
                HttpContext.TraceIdentifier));
        }

        if (!AllowedIconContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail(
                "Icon must be a PNG, WebP or JPEG file.",
                HttpContext.TraceIdentifier));
        }

        // Taken from the content type just validated, never from the uploaded file name: the name is
        // the caller's to choose and it ends up in a file path.
        var extension = file.ContentType.ToLowerInvariant() switch
        {
            "image/webp" => ".webp",
            "image/jpeg" => ".jpg",
            _ => ".png",
        };

        await using var stream = file.OpenReadStream();
        var iconUrl = await fileStorageService.SaveCategoryIconAsync(
            id,
            stream,
            extension,
            cancellationToken);

        var result = await mediator.Send(
            new SetServiceCategoryIconCommand { Id = id, IconUrl = iconUrl },
            cancellationToken);

        return Ok(result);
    }

    [HttpPost("categories/{categoryId:guid}/sub-categories")]
    public async Task<IActionResult> CreateSubCategory(
        Guid categoryId,
        SaveServiceSubCategoryCommand command,
        CancellationToken cancellationToken)
    {
        command.Id = null;
        command.ServiceCategoryId = categoryId;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPut("sub-categories/{id:guid}")]
    public async Task<IActionResult> UpdateSubCategory(
        Guid id,
        SaveServiceSubCategoryCommand command,
        CancellationToken cancellationToken)
    {
        command.Id = id;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }
}
