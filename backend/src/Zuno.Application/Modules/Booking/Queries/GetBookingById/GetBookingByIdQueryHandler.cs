using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Exceptions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.Queries.GetBookingById;

public class GetBookingByIdQueryHandler(
    ICurrentUserService currentUserService,
    IBookingWageService wageService,
    IBookingRepository bookingRepository) : IRequestHandler<GetBookingByIdQuery, BookingDto>
{
    public async Task<BookingDto> Handle(GetBookingByIdQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var booking = await bookingRepository.GetByIdAsync(request.BookingId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Domain.Entities.Booking), request.BookingId);

        var myAssignment = booking.WorkerAssignments.FirstOrDefault(a => a.WorkerProfile.UserId == userId);

        var isParticipant = booking.CustomerProfile.UserId == userId
            || booking.BusinessOwnerProfile.UserId == userId
            || myAssignment is not null;

        if (!isParticipant)
        {
            throw new UnauthorizedAccessException("This booking does not belong to you.");
        }

        // Only the business is shown wages, so only the business is worth the query.
        var isBusiness = booking.BusinessOwnerProfile.UserId == userId;
        var wages = isBusiness
            ? await wageService.GetAsync(booking.Id, cancellationToken)
            : (BookingWageRollup?)null;

        return booking.ToDto(myAssignment?.WorkerProfileId, wages: wages);
    }
}
