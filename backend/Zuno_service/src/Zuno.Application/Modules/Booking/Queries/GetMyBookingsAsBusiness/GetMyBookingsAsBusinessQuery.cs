using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingsAsBusiness;

public class GetMyBookingsAsBusinessQuery : IRequest<List<BookingDto>>;
