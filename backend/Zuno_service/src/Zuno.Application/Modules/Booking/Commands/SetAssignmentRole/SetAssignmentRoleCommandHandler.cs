using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.Commands.SetAssignmentRole;

public class SetAssignmentRoleCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext) : IRequestHandler<SetAssignmentRoleCommand, BookingDto>
{
    public async Task<BookingDto> Handle(
        SetAssignmentRoleCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // The owner alone, deliberately. A role carries the power to declare the work started and
        // finished, so a lead who could appoint another lead would be handing on authority the
        // owner never gave them.
        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (booking.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This booking does not belong to your business.");
        }

        // A role only means something while there is a job to run.
        //
        // Before the business confirms the order there is no job yet — the customer may never get
        // one. After the work is finished, or the order called off, there is nothing left to lead:
        // the job cannot be started or completed again, so a role given now would be a title
        // attached to history.
        if (!BookingWorkControl.CanHoldRoles(booking.BookingStatus))
        {
            throw new DomainException(booking.BookingStatus switch
            {
                BookingStatus.Pending =>
                    "Confirm this order first. There is no job to lead until you accept it.",
                BookingStatus.Completed =>
                    "This job is finished, so there is nothing left to lead.",
                BookingStatus.Cancelled =>
                    "This order was cancelled, so there is nothing left to lead.",
                _ => "A role cannot be set on this order.",
            });
        }

        var assignment = booking.WorkerAssignments
            .FirstOrDefault(a => a.WorkerProfileId == request.WorkerProfileId)
            ?? throw new DomainException("That worker is not on this job.");

        // A role can only go to somebody who has said yes.
        //
        // Not merely tidiness. A role is what lets its holder declare this job started and
        // finished, and until a worker answers they might still decline — so the owner would be
        // handing that power to somebody who is not coming. Worse, the role would appear set on the
        // owner's screen while doing nothing, because BookingWorkControl requires an accepted
        // assignment before it grants anything. Refusing here keeps the two in step.
        //
        // Completed counts: a lead who has ticked off their own part is still the lead, and that is
        // the moment they are most likely to be closing the job.
        if (assignment.AssignmentStatus is not (BookingWorkerAssignmentStatus.Accepted
            or BookingWorkerAssignmentStatus.Completed))
        {
            throw new DomainException(assignment.AssignmentStatus switch
            {
                BookingWorkerAssignmentStatus.Assigned =>
                    "They have not accepted this job yet. You can give them a role once they do.",
                BookingWorkerAssignmentStatus.Rejected =>
                    "That worker turned this job down, so they cannot be given a role on it.",
                _ => "That worker cannot be given a role on this job.",
            });
        }

        var role = request.Role?.Trim();

        // Blank is how a role is taken away, so the app needs no second endpoint for "remove".
        // Canonicalised so the stored value is always one of the three as written, not as typed.
        assignment.Role = JobRole.Canonical(role);

        await dbContext.SaveChangesAsync(cancellationToken);

        return booking.ToDto(includeCrew: true);
    }
}
