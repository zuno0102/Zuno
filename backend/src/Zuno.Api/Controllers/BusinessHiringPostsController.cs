using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Api.Contracts;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.HiringPost.Commands.CompleteHiringPostWork;
using Zuno.Application.Modules.HiringPost.Commands.ConfirmHiringPostApplication;
using Zuno.Application.Modules.HiringPost.Commands.ConfirmPayoutCollection;
using Zuno.Application.Modules.HiringPost.Commands.CreatePayoutBatch;
using Zuno.Application.Modules.HiringPost.Commands.CreateHiringPost;
using Zuno.Application.Modules.HiringPost.Commands.DeleteHiringPost;
using Zuno.Application.Modules.HiringPost.Commands.InviteWorkerToHiringPost;
using Zuno.Application.Modules.HiringPost.Commands.RaiseAgreedSalary;
using Zuno.Application.Modules.HiringPost.Commands.RejectHiringPostApplication;
using Zuno.Application.Modules.HiringPost.Commands.SetHiringPostImage;
using Zuno.Application.Modules.HiringPost.Commands.StartHiringPostWork;
using Zuno.Application.Modules.HiringPost.Commands.StopHiringPost;
using Zuno.Application.Modules.HiringPost.Commands.UpdateHiringPost;
using Zuno.Application.Modules.HiringPost.Queries.GetMyHiringPosts;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/business/hiring-posts")]
[Authorize(Policy = AuthorizationPolicyNames.RequireBusinessOwnerRole)]
public class BusinessHiringPostsController(
    ISender mediator,
    IOptions<FileStorageSettings> fileStorageSettings) : ControllerBase
{
    private static readonly HashSet<string> AllowedImageContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    };

    [HttpGet]
    public async Task<IActionResult> GetMyPosts(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyHiringPostsQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateHiringPostCommand command, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpdateHiringPostCommand command, CancellationToken cancellationToken)
    {
        command.HiringPostId = id;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Deletes a finished hiring post. Refused while the event is still upcoming.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await mediator.Send(new DeleteHiringPostCommand { HiringPostId = id }, cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// Invites a specific worker onto this post by email or phone. Creates a pending offer they
    /// answer themselves — it does not hire them outright.
    /// </summary>
    [HttpPost("{id:guid}/invite")]
    public async Task<IActionResult> InviteWorker(
        Guid id,
        InviteWorkerToHiringPostCommand command,
        CancellationToken cancellationToken)
    {
        command.HiringPostId = id;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Marks the work done, releasing the crew for other jobs even if the scheduled end time
    /// has not been reached.
    /// </summary>
    /// <summary>
    /// Marks the crew as having started on the day, which is what moves the job from scheduled
    /// to actually under way.
    /// </summary>
    [HttpPost("{id:guid}/start")]
    public async Task<IActionResult> StartWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new StartHiringPostWorkCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> CompleteWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new CompleteHiringPostWorkCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/stop-hiring")]
    public async Task<IActionResult> StopHiring(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new StopHiringPostCommand { HiringPostId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// "Pay all" — opens a pay run for everyone still owed on this job.
    /// </summary>
    /// <remarks>
    /// The response carries the server's own total. Any amount the caller sends is treated as a
    /// cross-check and, if it disagrees, the request is refused rather than either figure being used.
    /// </remarks>
    [HttpPost("{id:guid}/payouts")]
    public async Task<IActionResult> CreatePayoutBatch(
        Guid id,
        [FromBody] CreatePayoutBatchRequest? request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new CreatePayoutBatchCommand(id, request?.ExpectedTotal), cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// The business's single PIN has cleared — funds the run and splits it to every worker.
    /// </summary>
    [HttpPost("payouts/{payoutBatchId:guid}/confirm")]
    public async Task<IActionResult> ConfirmPayoutCollection(
        Guid payoutBatchId,
        [FromBody] ConfirmPayoutCollectionRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new ConfirmPayoutCollectionCommand(payoutBatchId, request.ProviderPaymentId, request.Signature), cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/image")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> SetImage(Guid id, IFormFile file, CancellationToken cancellationToken)
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

        var extension = Path.GetExtension(file.FileName) is { Length: > 0 } ext ? ext : ".jpg";

        // Handed to the command rather than saved here, so nothing is written until the post is
        // known to be the caller's — see SetBusinessServiceImageCommand.
        await using var stream = file.OpenReadStream();

        var result = await mediator.Send(
            new SetHiringPostImageCommand
            {
                HiringPostId = id,
                Content = stream,
                FileExtension = extension,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("applications/{applicationId:guid}/confirm")]
    public async Task<IActionResult> ConfirmApplication(Guid applicationId, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new ConfirmHiringPostApplicationCommand { ApplicationId = applicationId }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("applications/{applicationId:guid}/reject")]
    public async Task<IActionResult> RejectApplication(Guid applicationId, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new RejectHiringPostApplicationCommand { ApplicationId = applicationId }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Raises a confirmed worker's agreed salary — e.g. for extra hours. Increases only.</summary>
    [HttpPost("applications/{applicationId:guid}/salary")]
    public async Task<IActionResult> RaiseAgreedSalary(
        Guid applicationId,
        RaiseAgreedSalaryCommand command,
        CancellationToken cancellationToken)
    {
        command.ApplicationId = applicationId;
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }
}
