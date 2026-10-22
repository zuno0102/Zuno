using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.RaiseCrewMemberSalary;

public class RaiseCrewMemberSalaryCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext) : IRequestHandler<RaiseCrewMemberSalaryCommand, BookingDto>
{
    public async Task<BookingDto> Handle(RaiseCrewMemberSalaryCommand request, CancellationToken cancellationToken)
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

        var assignment = booking.WorkerAssignments
            .FirstOrDefault(a => a.WorkerProfileId == request.WorkerProfileId)
            ?? throw new DomainException("That worker is not on this job.");

        dbContext.BookingAssignmentSalaryAdjustments.Add(assignment.RaiseSalary(request.Increase, request.Reason));

        await dbContext.SaveChangesAsync(cancellationToken);

        return booking.ToDto(includeCrew: true);
    }
}
