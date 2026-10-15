using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Notifications.DTOs;

namespace Zuno.Application.Modules.Notifications.Queries.GetMyNotifications;

public class GetMyNotificationsQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetMyNotificationsQuery, List<NotificationDto>>
{
    // A phone shows a few screens of these and nobody scrolls a year back. The cap is here rather
    // than trusted from the request so a client cannot ask for somebody's entire history.
    private const int MaxTake = 100;

    public async Task<List<NotificationDto>> Handle(
        GetMyNotificationsQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var take = Math.Clamp(request.Take, 1, MaxTake);

        var query = dbContext.Notifications
            .Where(n => n.UserId == userId);

        if (request.UnreadOnly)
        {
            query = query.Where(n => n.ReadAt == null);
        }

        var rows = await query
            // Newest first, which is the order the index on (user_id, created_date) already holds.
            .OrderByDescending(n => n.CreatedDate)
            .Take(take)
            .Select(n => new
            {
                n.Id,
                n.Kind,
                n.Title,
                n.Body,
                n.Target,
                n.TargetId,
                n.ReadAt,
                n.CreatedDate,
            })
            .ToListAsync(cancellationToken);

        return rows
            .Select(n => new NotificationDto
            {
                Id = n.Id,
                Kind = n.Kind.ToString(),
                Title = n.Title,
                Body = n.Body,
                Target = n.Target.ToString(),
                // Guid.Empty is how "no id" is stored; the app should get nothing rather than a row
                // of zeroes to test against.
                TargetId = n.TargetId == Guid.Empty ? null : n.TargetId,
                IsUnread = n.ReadAt is null,
                CreatedAt = n.CreatedDate,
            })
            .ToList();
    }
}
