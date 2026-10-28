using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.Common;
using Zuno.Application.Modules.Notifications.DTOs;

namespace Zuno.Application.Modules.Notifications.Queries.GetUnreadNotificationCount;

public class GetUnreadNotificationCountQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetUnreadNotificationCountQuery, NotificationCountDto>
{
    public async Task<NotificationCountDto> Handle(
        GetUnreadNotificationCountQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Chat is left out, for the reason given on OnTheBell.
        //
        // Served by the filtered index on (user_id, read_at) where read_at is null, so this stays a
        // cheap call however long somebody's history grows.
        var count = await dbContext.Notifications
            .OnTheBell()
            .CountAsync(
                n => n.UserId == userId && n.ReadAt == null,
                cancellationToken);

        return new NotificationCountDto { UnreadCount = count };
    }
}
