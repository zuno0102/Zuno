using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsCustomer;

public class GetMyBookingsAsCustomerQuery : IRequest<List<BookingDto>>;
