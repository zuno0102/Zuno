using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.Booking.Commands.AssignWorker;
using Zuno.Application.Modules.Booking.Commands.SetAssignmentRole;
using Zuno.Application.Modules.Booking.Commands.CancelBooking;
using Zuno.Application.Modules.Booking.Commands.CompleteBookingWork;
using Zuno.Application.Modules.Booking.Commands.AcceptBookingTerms;
using Zuno.Application.Modules.Booking.Commands.ConfirmBooking;
using Zuno.Application.Modules.Booking.Commands.ProposeBookingTerms;
using Zuno.Application.Modules.Booking.Commands.RaiseCrewMemberSalary;
using Zuno.Application.Modules.Booking.Commands.RaiseOrderCrewSalary;
using Zuno.Application.Modules.Booking.Commands.StartBookingWork;
using Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;
using Zuno.Application.Modules.Booking.Queries.GetBookingById;
using Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsBusiness;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/business/bookings")]
[Authorize(Policy = AuthorizationPolicyNames.RequireBusinessOwnerRole)]
public class BusinessBookingsController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMyBookings(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetMyBookingsAsBusinessQuery(), cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetBookingByIdQuery { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/confirm")]
    public async Task<IActionResult> Confirm(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new ConfirmBookingCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Offers the customer a crew size and a price for this order.</summary>
    /// <remarks>
    /// The business reads what the customer said about the job, then proposes what it takes. The
    /// customer accepts or counters; accepting is what confirms the order.
    /// </remarks>
    [HttpPost("{id:guid}/terms")]
    public async Task<IActionResult> ProposeTerms(
        Guid id,
        ProposeBookingTermsCommand command,
        CancellationToken cancellationToken)
    {
        command.BookingId = id;

        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>Takes up the customer's counter-offer, confirming the order.</summary>
    /// <remarks>
    /// The offer is named by id rather than "whatever is open", so a counter landing at the same
    /// moment is reported as replaced instead of being accepted by mistake.
    /// </remarks>
    [HttpPost("{id:guid}/terms/{proposalId:guid}/accept")]
    public async Task<IActionResult> AcceptTerms(
        Guid id,
        Guid proposalId,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new AcceptBookingTermsCommand { BookingId = id, ProposalId = proposalId },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Marks a confirmed order as actually under way.</summary>
    [HttpPost("{id:guid}/start")]
    public async Task<IActionResult> StartWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new StartBookingWorkCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Marks the work on an order as finished, closing the crew with it.</summary>
    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> CompleteWork(Guid id, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new CompleteBookingWorkCommand { BookingId = id }, cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/assign-worker")]
    public async Task<IActionResult> AssignWorker(Guid id, [FromBody] AssignWorkerRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new AssignWorkerCommand
            {
                BookingId = id,
                WorkerProfileId = request.WorkerProfileId,
                ScheduledDate = request.ScheduledDate,
                SalaryAmount = request.SalaryAmount,
                SalaryUnit = request.SalaryUnit,
            },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Gives one of this order's crew a role on this job, or takes it away.</summary>
    /// <remarks>
    /// On the worker rather than the assignment row, because that is what the owner has in front of
    /// them on the crew list. A blank role removes it, so there is no separate delete to get wrong.
    /// </remarks>
    [HttpPut("{id:guid}/crew/{workerProfileId:guid}/role")]
    public async Task<IActionResult> SetCrewRole(
        Guid id,
        Guid workerProfileId,
        [FromBody] SetCrewRoleRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new SetAssignmentRoleCommand
            {
                BookingId = id,
                WorkerProfileId = workerProfileId,
                Role = request.Role,
            },
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/crew-size")]
    public async Task<IActionResult> UpdateCrewSize(Guid id, [FromBody] UpdateCrewSizeRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new UpdateCrewSizeCommand { BookingId = id, RequiredWorkerCount = request.RequiredWorkerCount },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Adds extra pay to one worker added to this order directly. Increases only.</summary>
    [HttpPost("{id:guid}/crew/{workerProfileId:guid}/raise-salary")]
    public async Task<IActionResult> RaiseCrewMemberSalary(
        Guid id,
        Guid workerProfileId,
        [FromBody] RaiseSalaryRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new RaiseCrewMemberSalaryCommand
            {
                BookingId = id,
                WorkerProfileId = workerProfileId,
                Increase = request.Increase,
                Reason = request.Reason,
            },
            cancellationToken);
        return Ok(result);
    }

    /// <summary>Adds the same extra pay to everyone on this order still to be paid.</summary>
    [HttpPost("{id:guid}/crew/raise-salary")]
    public async Task<IActionResult> RaiseOrderCrewSalary(
        Guid id,
        [FromBody] RaiseSalaryRequest request,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(
            new RaiseOrderCrewSalaryCommand { BookingId = id, Increase = request.Increase, Reason = request.Reason },
            cancellationToken);
        return Ok(result);
    }

    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] CancelBookingRequest request, CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new CancelBookingCommand { BookingId = id, Reason = request.Reason }, cancellationToken);
        return Ok(result);
    }
}

/// <summary>Extra pay on top of the current wage: ₹200 on ₹1,000 makes ₹1,200.</summary>
public class RaiseSalaryRequest
{
    public decimal Increase { get; set; }

    public string? Reason { get; set; }
}

/// <summary>What a crew member is on this job. Blank takes the role away.</summary>
public class SetCrewRoleRequest
{
    public string? Role { get; set; }
}

public class AssignWorkerRequest
{
    public Guid WorkerProfileId { get; set; }

    public DateTimeOffset? ScheduledDate { get; set; }

    /// <summary>What this worker is paid for this job. Omitted when they are paid outside Zuno.</summary>
    public decimal? SalaryAmount { get; set; }

    /// <summary>PerEvent, PerDay or PerHour. Required whenever an amount is given.</summary>
    public string? SalaryUnit { get; set; }
}

public class UpdateCrewSizeRequest
{
    public int RequiredWorkerCount { get; set; }
}
