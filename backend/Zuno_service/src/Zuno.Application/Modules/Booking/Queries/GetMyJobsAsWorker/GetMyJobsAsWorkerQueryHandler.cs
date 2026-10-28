using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Queries.GetMyJobsAsWorker;

public class GetMyJobsAsWorkerQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext,
    IBookingRepository bookingRepository) : IRequestHandler<GetMyJobsAsWorkerQuery, List<BookingDto>>
{
    public async Task<List<BookingDto>> Handle(GetMyJobsAsWorkerQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var workerProfile = await dbContext.WorkerProfiles
            .FirstOrDefaultAsync(wp => wp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        var bookings = await bookingRepository.GetByWorkerIdAsync(workerProfile.Id, cancellationToken);

        return bookings.Select(b => b.ToDto(workerProfile.Id)).ToList();
    }
}
