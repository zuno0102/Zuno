using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.WorkChat.Common;
using Zuno.Application.Modules.WorkChat.DTOs;

namespace Zuno.Application.Modules.WorkChat.Queries.GetWorkMessages;

public class GetWorkMessagesQueryHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetWorkMessagesQuery, List<WorkMessageDto>>
{
    /// <summary>
    /// How much of a long relationship one read returns. The newest are kept; a conversation that
    /// has run for months does not need its first message on every poll.
    /// </summary>
    private const int MaxMessages = 300;

    public async Task<List<WorkMessageDto>> Handle(
        GetWorkMessagesQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var reader = await WorkThreadAccess.ResolveAsync(
            dbContext,
            userId,
            request.CounterpartId,
            cancellationToken);

        var messages = await dbContext.WorkMessages
            .Where(m => m.BusinessOwnerProfileId == reader.BusinessOwnerProfileId
                && m.WorkerProfileId == reader.WorkerProfileId)
            .OrderByDescending(m => m.CreatedDate)
            .Take(MaxMessages)
            .ToListAsync(cancellationToken);

        // Oldest first for reading, as in a booking thread.
        messages.Reverse();

        // Everything from the other side is now read.
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

        var senderIds = messages.Select(m => m.SenderUserId).Distinct().ToList();
        var senderNames = await dbContext.Users
            .Where(u => senderIds.Contains(u.Id))
            .Select(u => new { u.Id, Name = u.FirstName + " " + u.LastName })
            .ToDictionaryAsync(u => u.Id, u => u.Name.Trim(), cancellationToken);

        return
        [
            .. messages.Select(m => new WorkMessageDto
            {
                Id = m.Id,
                CounterpartId = request.CounterpartId,
                SenderRole = m.SenderRole.ToString(),
                IsMine = m.SenderRole == reader.Role,
                SenderName = senderNames.GetValueOrDefault(m.SenderUserId, string.Empty),
                Body = m.Body,
                SentAt = m.CreatedDate,
                ReadAt = m.ReadAt,
            }),
        ];
    }
}
