using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsCustomer;

public class GetMyBookingsAsCustomerQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext,
    IBookingRepository bookingRepository) : IRequestHandler<GetMyBookingsAsCustomerQuery, List<BookingDto>>
{
    public async Task<List<BookingDto>> Handle(GetMyBookingsAsCustomerQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var customerProfile = await dbContext.CustomerProfiles
            .FirstOrDefaultAsync(cp => cp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(CustomerProfile), userId);

        var bookings = await bookingRepository.GetByCustomerIdAsync(customerProfile.Id, cancellationToken);

        // Customers do not receive staffing: it is the business's arrangement, and the crew
        // list carries workers' names and phone numbers.
        return bookings.Select(b => b.ToDto(includeCrew: false)).ToList();
    }
}
