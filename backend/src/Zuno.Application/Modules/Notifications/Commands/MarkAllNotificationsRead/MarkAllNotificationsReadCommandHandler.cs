using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Notifications.Commands.MarkAllNotificationsRead;

public class MarkAllNotificationsReadCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<MarkAllNotificationsReadCommand, Unit>
{
    public async Task<Unit> Handle(
        MarkAllNotificationsReadCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var now = dateTimeProvider.UtcNow;

        // Loaded and tracked rather than updated in place with ExecuteUpdate, so the audit
        // interceptor stamps ModifiedBy/ModifiedDate the way it does everywhere else in this schema.
        // The filtered index keeps this to the unread ones, which is a handful even for a busy
        // worker who has ignored the bell for a week.
        var unread = await dbContext.Notifications
            .Where(n => n.UserId == userId && n.ReadAt == null)
            .ToListAsync(cancellationToken);

        if (unread.Count == 0)
        {
            return Unit.Value;
        }

        foreach (var notification in unread)
        {
            notification.ReadAt = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}
