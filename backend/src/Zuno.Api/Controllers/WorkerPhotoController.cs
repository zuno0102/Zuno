using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Zuno.Api.Uploads;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Worker.Commands.SetWorkerPhoto;
using Zuno.Application.Modules.Worker.Queries.GetMyWorkerProfile;

namespace Zuno.Api.Controllers;

/// <summary>
/// The worker's own profile picture.
/// </summary>
/// <remarks>
/// Its own controller because it takes a file rather than JSON, mirroring how a business logo is
/// handled. A picture matters more for a worker than it looks: a business deciding between two
/// strangers for an evening's work has very little else to go on.
/// </remarks>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/profile/photo")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerPhotoController(
    ISender mediator,
    IFileStorageService fileStorageService,
    IOptions<FileStorageSettings> fileStorageSettings) : ControllerBase
{

    /// <summary>Uploads or replaces the signed-in worker's picture.</summary>
    [HttpPut]
    public async Task<IActionResult> SetPhoto(IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            return BadRequest(ApiResponse.Fail("No file was uploaded.", HttpContext.TraceIdentifier));
        }

        if (file.Length > fileStorageSettings.Value.MaxFileSizeBytes)
        {
            return BadRequest(ApiResponse.Fail(
                $"Image must be {fileStorageSettings.Value.MaxFileSizeBytes / (1024 * 1024)}MB or smaller.",
                HttpContext.TraceIdentifier));
        }

        // Judged by the file's first bytes; the stored extension comes from what it really is.
        var extension = await MediaUpload.ImageExtensionAsync(file, cancellationToken);
        if (extension is null)
        {
            return BadRequest(ApiResponse.Fail(MediaUpload.ImageRule, HttpContext.TraceIdentifier));
        }


        // Stored under the worker's own profile id, read from the token — there is no id in the route
        // for a caller to swap for somebody else's.
        var profile = await mediator.Send(new GetMyWorkerProfileQuery(), cancellationToken);

        await using var stream = file.OpenReadStream();
        var photoUrl = await fileStorageService.SaveWorkerPhotoAsync(
            profile.Id,
            stream,
            extension,
            cancellationToken);

        var result = await mediator.Send(
            new SetWorkerPhotoCommand { Url = photoUrl },
            cancellationToken);

        return Ok(result);
    }

}
