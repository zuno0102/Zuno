using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsBusiness;

public class GetMyBookingsAsBusinessQueryHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBookingWageService wageService,
    IBookingRepository bookingRepository) : IRequestHandler<GetMyBookingsAsBusinessQuery, List<BookingDto>>
{
    public async Task<List<BookingDto>> Handle(GetMyBookingsAsBusinessQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var bookings = await bookingRepository.GetByBusinessIdAsync(businessProfile.Id, cancellationToken);

        // One query for the whole list, not one per order.
        var wages = await wageService.GetManyAsync(
            bookings.Select(b => b.Id).ToList(), cancellationToken);

        return bookings
            .Select(b => b.ToDto(
                wages: wages.GetValueOrDefault(b.Id, BookingWageRollup.None)))
            .ToList();
    }
}
