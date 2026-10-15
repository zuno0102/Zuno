using MediatR;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetMyJobsAsWorker;

public class GetMyJobsAsWorkerQuery : IRequest<List<BookingDto>>;
