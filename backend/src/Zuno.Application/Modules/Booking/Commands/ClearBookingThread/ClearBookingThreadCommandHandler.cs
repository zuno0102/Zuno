using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Booking.Commands.ClearBookingThread;

public class ClearBookingThreadCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<ClearBookingThreadCommand, Unit>
{
    public async Task<Unit> Handle(
        ClearBookingThreadCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Same gate as reading it: only the two parties, and a stranger is refused rather than
        // quietly allowed to write a row against somebody else's booking.
        await BookingThreadAccess.ResolveAsync(
            dbContext,
            request.BookingId,
            userId,
            cancellationToken);

        var now = dateTimeProvider.UtcNow;

        var existing = await dbContext.BookingThreadClears
            .FirstOrDefaultAsync(
                c => c.BookingId == request.BookingId && c.UserId == userId,
                cancellationToken);

        if (existing is null)
        {
            dbContext.BookingThreadClears.Add(new BookingThreadClear
            {
                BookingId = request.BookingId,
                UserId = userId,
                ClearedAt = now,
                CreatedDate = now,
            });
        }
        else
        {
            // Moved forward rather than added to, so clearing a thread twice hides everything up to
            // the second time rather than leaving the older mark in charge.
            existing.ClearedAt = now;
            existing.ModifiedDate = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}
