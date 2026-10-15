using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Booking.DTOs;

namespace Zuno.Application.Modules.Booking.Queries.GetBookingMessages;

public class GetBookingMessagesQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetBookingMessagesQuery, List<BookingMessageDto>>
{
    public async Task<List<BookingMessageDto>> Handle(
        GetBookingMessagesQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var reader = await BookingThreadAccess.ResolveAsync(
            dbContext,
            request.BookingId,
            userId,
            cancellationToken);

        // Where this person last cleared the thread, if they ever did. Everything up to it is theirs
        // to have hidden; the other side still sees all of it.
        var clearedAt = await dbContext.BookingThreadClears
            .Where(c => c.BookingId == request.BookingId && c.UserId == userId)
            .Select(c => (DateTimeOffset?)c.ClearedAt)
            .FirstOrDefaultAsync(cancellationToken);

        var messages = await dbContext.BookingMessages
            .Where(m => m.BookingId == request.BookingId)
            .Where(m => clearedAt == null || m.CreatedDate > clearedAt)
            // Oldest first: a conversation reads downwards, and the client scrolls to the bottom.
            .OrderBy(m => m.CreatedDate)
            .ToListAsync(cancellationToken);

        // Everything from the other side is now read. Marked before the DTOs are built so what comes
        // back matches what the database says, rather than a list that still claims to be unread.
        var unread = messages
            .Where(m => m.SenderRole != reader.Role && m.ReadAt is null)
            .ToList();

        if (unread.Count > 0)
        {
            var now = dateTimeProvider.UtcNow;

            foreach (var message in unread)
            {
                message.ReadAt = now;
            }

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        // One lookup for the names, rather than a join per message: a thread has two authors at most,
        // and both are already known from resolving access.
        var senderNames = await dbContext.Users
            .Where(u => messages.Select(m => m.SenderUserId).Contains(u.Id))
            .Select(u => new { u.Id, Name = u.FirstName + " " + u.LastName })
            .ToListAsync(cancellationToken);

        return
        [
            .. messages.Select(m => new BookingMessageDto
            {
                Id = m.Id,
                BookingId = m.BookingId,
                SenderRole = m.SenderRole.ToString(),
                IsMine = m.SenderRole == reader.Role,
                SenderName = senderNames
                    .FirstOrDefault(u => u.Id == m.SenderUserId)?.Name.Trim() ?? string.Empty,
                Body = m.Body,
                SentAt = m.CreatedDate,
                ReadAt = m.ReadAt,
            }),
        ];
    }
}
