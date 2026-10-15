using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Business.Commands.CreateBusinessService;
using Zuno.Application.Modules.Business.Commands.CreateBusinessServiceVariant;
using Zuno.Application.Modules.Business.Commands.DeleteBusinessService;
using Zuno.Application.Modules.Business.Commands.DeleteBusinessServiceVariant;
using Zuno.Application.Modules.Business.Commands.InviteWorker;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantImage;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantVideo;
using Zuno.Application.Modules.Business.Commands.RemoveBusinessWorker;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantImage;
using Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantVideo;
using Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;
using Zuno.Application.Modules.Business.Commands.UpdateBusinessService;
using Zuno.Application.Modules.Business.Commands.UpdateBusinessServiceVariant;
using Zuno.Application.Modules.Business.Queries.GetBusinessServices;
using Zuno.Application.Modules.Business.Queries.GetBusinessWorkers;
using Zuno.Application.Modules.Business.Queries.GetBusinessDashboard;
using Zuno.Application.Modules.Business.Commands.SetBusinessLogo;
using Zuno.Application.Modules.Business.Queries.GetMyBusinessProfile;
using Zuno.Application.Modules.Business.Queries.GetWorkerBusyDates;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/business")]
[Authorize(Policy = AuthorizationPolicyNames.RequireBusinessOwnerRole)]
public class BusinessController(
    ISender mediator,
    IFileStorageService fileStorageService,
    IOptions<FileStorageSettings> fileStorageSettings) : ControllerBase
{
    private static readonly HashSet<string> AllowedImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    };

    private static readonly HashSet<string> AllowedVideoContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "video/mp4",
        "video/quicktime",
        "video/webm",
    };

    /// <summary>The business home screen: work delivered, split by category, plus trust.</summary>
    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBusinessDashboardQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpGet("profile")]
    public async Task<IActionResult> GetMyProfile(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyBusinessProfileQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateMyProfile(UpdateBusinessProfileCommand command, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Sets the signed-in business's profile picture.</summary>
    /// <remarks>
    /// The multipart part must be named <c>file</c> — binding matches the parameter name, and
    /// there is no <c>[Consumes]</c> attribute to say so more loudly.
    /// </remarks>
    [HttpPost("profile/logo")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadProfileLogo(IFormFile file, CancellationToken cancellationToken)
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

        if (!AllowedImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail("Image must be a JPEG, PNG, or WebP file.", HttpContext.TraceIdentifier));
        }

        // Taken from the content type we just validated, not from the uploaded file name. The
        // name is the client's to choose, and it ends up in a file path.
        var extension = ExtensionForImageContentType(file.ContentType);

        // The picture is stored under the profile's own id, so a business can only ever write
        // to its own folder — there is no id in the route for a caller to tamper with.
        var profile = await mediator.Send(new GetMyBusinessProfileQuery(), cancellationToken);

        await using var stream = file.OpenReadStream();
        var logoUrl = await fileStorageService.SaveBusinessLogoAsync(
            profile.Id, stream, extension, cancellationToken);

        var result = await mediator.Send(new SetBusinessLogoCommand { Url = logoUrl }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Removes the signed-in business's profile picture.</summary>
    [HttpDelete("profile/logo")]
    public async Task<IActionResult> RemoveProfileLogo(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new SetBusinessLogoCommand { Url = null }, cancellationToken);
        return Ok(result);
    }

    /// <summary>The file extension matching an already-validated image content type.</summary>
    private static string ExtensionForImageContentType(string contentType) => contentType.ToLowerInvariant() switch
    {
        "image/png" => ".png",
        "image/webp" => ".webp",
        _ => ".jpg",
    };

    [HttpGet("services")]
    public async Task<IActionResult> GetServices(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBusinessServicesQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost("services")]
    public async Task<IActionResult> CreateService(CreateBusinessServiceCommand command, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPut("services/{id:guid}")]
    public async Task<IActionResult> UpdateService(Guid id, UpdateBusinessServiceCommand command, CancellationToken cancellationToken)
    {
        command.Id = id;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Sets what this service asks a customer before they can book it.</summary>
    /// <remarks>
    /// The whole ordered set at once. The business edits these as a list and saves once, so
    /// separate add/edit/delete calls would mean several round-trips and a half-saved set if one
    /// of them failed.
    /// </remarks>
    [HttpPut("services/{id:guid}/questions")]
    public async Task<IActionResult> SetServiceQuestions(
        Guid id,
        SetBusinessServiceQuestionsCommand command,
        CancellationToken cancellationToken)
    {
        command.ServiceId = id;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}")]
    public async Task<IActionResult> DeleteService(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteBusinessServiceCommand { Id = id }, cancellationToken);
        return NoContent();
    }

    [HttpPost("services/{id:guid}/images/{slot:int}")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadServiceImage(Guid id, int slot, IFormFile file, CancellationToken cancellationToken)
    {
        if (slot is < 0 or > 2)
        {
            return BadRequest(ApiResponse.Fail("Image slot must be between 0 and 2.", HttpContext.TraceIdentifier));
        }

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

        if (!AllowedImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail("Image must be a JPEG, PNG, or WebP file.", HttpContext.TraceIdentifier));
        }

        var extension = Path.GetExtension(file.FileName) is { Length: > 0 } ext ? ext : ".jpg";

        // The file is handed to the command rather than saved here. Saving it here wrote it to
        // disk before anything had checked the service was the caller's, and the storage layer
        // clears the slot before writing — so an upload aimed at another business's service id
        // deleted their picture and replaced it with this one.
        await using var stream = file.OpenReadStream();

        var result = await mediator.Send(
            new SetBusinessServiceImageCommand
            {
                ServiceId = id,
                SlotIndex = slot,
                Content = stream,
                FileExtension = extension,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}/images/{slot:int}")]
    public async Task<IActionResult> RemoveServiceImage(Guid id, int slot, CancellationToken cancellationToken)
    {
        await mediator.Send(new RemoveBusinessServiceImageCommand { ServiceId = id, SlotIndex = slot }, cancellationToken);
        return NoContent();
    }

    [HttpPost("services/{id:guid}/video")]
    [RequestSizeLimit(30_000_000)]
    public async Task<IActionResult> UploadServiceVideo(Guid id, IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            return BadRequest(ApiResponse.Fail("No file was uploaded.", HttpContext.TraceIdentifier));
        }

        if (file.Length > fileStorageSettings.Value.MaxVideoFileSizeBytes)
        {
            return BadRequest(ApiResponse.Fail(
                $"Video must be {fileStorageSettings.Value.MaxVideoFileSizeBytes / (1024 * 1024)}MB or smaller.",
                HttpContext.TraceIdentifier));
        }

        if (!AllowedVideoContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail("Video must be an MP4, MOV, or WebM file.", HttpContext.TraceIdentifier));
        }

        var extension = Path.GetExtension(file.FileName) is { Length: > 0 } ext ? ext : ".mp4";

        await using var stream = file.OpenReadStream();

        var result = await mediator.Send(
            new SetBusinessServiceVideoCommand
            {
                ServiceId = id,
                Content = stream,
                FileExtension = extension,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}/video")]
    public async Task<IActionResult> RemoveServiceVideo(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new RemoveBusinessServiceVideoCommand { ServiceId = id }, cancellationToken);
        return NoContent();
    }

    [HttpPost("services/{id:guid}/variants")]
    public async Task<IActionResult> CreateServiceVariant(Guid id, CreateBusinessServiceVariantCommand command, CancellationToken cancellationToken)
    {
        command.ServiceId = id;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPut("services/{id:guid}/variants/{variantId:guid}")]
    public async Task<IActionResult> UpdateServiceVariant(
        Guid id, Guid variantId, UpdateBusinessServiceVariantCommand command, CancellationToken cancellationToken)
    {
        command.ServiceId = id;
        command.VariantId = variantId;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}/variants/{variantId:guid}")]
    public async Task<IActionResult> DeleteServiceVariant(Guid id, Guid variantId, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteBusinessServiceVariantCommand { ServiceId = id, VariantId = variantId }, cancellationToken);
        return NoContent();
    }

    [HttpPost("services/{id:guid}/variants/{variantId:guid}/images/{slot:int}")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadServiceVariantImage(
        Guid id, Guid variantId, int slot, IFormFile file, CancellationToken cancellationToken)
    {
        if (slot is < 0 or > 2)
        {
            return BadRequest(ApiResponse.Fail("Image slot must be between 0 and 2.", HttpContext.TraceIdentifier));
        }

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

        if (!AllowedImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail("Image must be a JPEG, PNG, or WebP file.", HttpContext.TraceIdentifier));
        }

        var extension = Path.GetExtension(file.FileName) is { Length: > 0 } ext ? ext : ".jpg";

        await using var stream = file.OpenReadStream();

        var result = await mediator.Send(
            new SetBusinessServiceVariantImageCommand
            {
                ServiceId = id,
                VariantId = variantId,
                SlotIndex = slot,
                Content = stream,
                FileExtension = extension,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}/variants/{variantId:guid}/images/{slot:int}")]
    public async Task<IActionResult> RemoveServiceVariantImage(Guid id, Guid variantId, int slot, CancellationToken cancellationToken)
    {
        await mediator.Send(
            new RemoveBusinessServiceVariantImageCommand { ServiceId = id, VariantId = variantId, SlotIndex = slot },
            cancellationToken);
        return NoContent();
    }

    [HttpPost("services/{id:guid}/variants/{variantId:guid}/video")]
    [RequestSizeLimit(30_000_000)]
    public async Task<IActionResult> UploadServiceVariantVideo(
        Guid id, Guid variantId, IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            return BadRequest(ApiResponse.Fail("No file was uploaded.", HttpContext.TraceIdentifier));
        }

        if (file.Length > fileStorageSettings.Value.MaxVideoFileSizeBytes)
        {
            return BadRequest(ApiResponse.Fail(
                $"Video must be {fileStorageSettings.Value.MaxVideoFileSizeBytes / (1024 * 1024)}MB or smaller.",
                HttpContext.TraceIdentifier));
        }

        if (!AllowedVideoContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail("Video must be an MP4, MOV, or WebM file.", HttpContext.TraceIdentifier));
        }

        var extension = Path.GetExtension(file.FileName) is { Length: > 0 } ext ? ext : ".mp4";

        await using var stream = file.OpenReadStream();

        var result = await mediator.Send(
            new SetBusinessServiceVariantVideoCommand
            {
                ServiceId = id,
                VariantId = variantId,
                Content = stream,
                FileExtension = extension,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpDelete("services/{id:guid}/variants/{variantId:guid}/video")]
    public async Task<IActionResult> RemoveServiceVariantVideo(Guid id, Guid variantId, CancellationToken cancellationToken)
    {
        await mediator.Send(
            new RemoveBusinessServiceVariantVideoCommand { ServiceId = id, VariantId = variantId },
            cancellationToken);
        return NoContent();
    }

    [HttpGet("workers")]
    public async Task<IActionResult> GetWorkers(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBusinessWorkersQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpGet("workers/{workerProfileId:guid}/busy-dates")]
    public async Task<IActionResult> GetWorkerBusyDates(Guid workerProfileId, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetWorkerBusyDatesQuery { WorkerProfileId = workerProfileId }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("workers/invite")]
    public async Task<IActionResult> InviteWorker(InviteWorkerCommand command, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // A worker's role is not set here any more. A title held across the whole business made the
    // same person the lead on every job at once; it now belongs to the one job, and is set from
    // that order's crew — see BusinessBookingsController.

    [HttpDelete("workers/{id:guid}")]
    public async Task<IActionResult> RemoveWorker(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new RemoveBusinessWorkerCommand { Id = id }, cancellationToken);
        return NoContent();
    }
}
