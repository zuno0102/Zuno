using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Booking.Commands.CompleteBooking;
using Zuno.Application.Modules.Booking.Commands.CompleteBookingWork;
using Zuno.Application.Modules.Booking.Commands.RespondToAssignment;
using Zuno.Application.Modules.Booking.Commands.StartBookingWork;
using Zuno.Application.Modules.Booking.Queries.GetBookingById;
using Zuno.Application.Modules.Booking.Queries.GetMyJobsAsWorker;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/worker/jobs")]
[Authorize(Policy = AuthorizationPolicyNames.RequireWorkerRole)]
public class WorkerJobsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMyJobs(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyJobsAsWorkerQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBookingByIdQuery { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/respond")]
    public async Task<IActionResult> Respond(Guid id, [FromBody] RespondToAssignmentRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new RespondToAssignmentCommand { BookingId = id, Accept = request.Accept },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>The worker marking their own part of the job finished.</summary>
    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new CompleteBookingCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    // ---- the job's lead -------------------------------------------------------------------
    // The two below move the WHOLE order, not this worker's own row, and are refused by the
    // handler for anyone the owner has not put in charge of this job.
    //
    // They exist here, rather than on the business controller, because that one is closed to the
    // BusinessOwner role before a request ever reaches a handler — and a lead is a worker.

    /// <summary>The job's lead saying the work has begun.</summary>
    [HttpPost("{id:guid}/start-job")]
    public async Task<IActionResult> StartJob(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new StartBookingWorkCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>The job's lead closing the whole order, finishing any crew still on it.</summary>
    [HttpPost("{id:guid}/finish-job")]
    public async Task<IActionResult> FinishJob(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new CompleteBookingWorkCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }
}

public class RespondToAssignmentRequest
{
    public bool Accept { get; set; }
}
