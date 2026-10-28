using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.UpdateCrewSize;

public class UpdateCrewSizeCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateCrewSizeCommand, BookingDto>
{
    public async Task<BookingDto> Handle(UpdateCrewSizeCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        if (booking.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This booking does not belong to your business.");
        }

        if (booking.BookingStatus is BookingStatus.Completed or BookingStatus.Cancelled)
        {
            throw new DomainException("This booking's crew size can no longer be changed.");
        }

        var activeCrewCount = booking.WorkerAssignments.Count(a =>
            a.AssignmentStatus is BookingWorkerAssignmentStatus.Assigned or BookingWorkerAssignmentStatus.Accepted);
        if (request.RequiredWorkerCount < activeCrewCount)
        {
            throw new DomainException(
                $"This order already has {activeCrewCount} worker(s) assigned — the crew size cannot be set lower than that.");
        }

        booking.RequiredWorkerCount = request.RequiredWorkerCount;

        await dbContext.SaveChangesAsync(cancellationToken);

        return booking.ToDto();
    }
}
