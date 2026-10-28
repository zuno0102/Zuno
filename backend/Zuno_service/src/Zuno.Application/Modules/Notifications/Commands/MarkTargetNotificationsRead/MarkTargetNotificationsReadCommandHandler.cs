using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Notifications.Commands.MarkTargetNotificationsRead;

public class MarkTargetNotificationsReadCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<MarkTargetNotificationsReadCommand, Unit>
{
    public async Task<Unit> Handle(
        MarkTargetNotificationsReadCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // A target with no id names a whole screen — "the worker's payments", "their profile" —
        // and marking those read because somebody opened a tab is exactly the blanket clearing
        // this command exists to avoid.
        if (request.TargetId == Guid.Empty)
        {
            return Unit.Value;
        }

        var now = dateTimeProvider.UtcNow;

        // Tracked rather than ExecuteUpdate, so the audit interceptor stamps these the way it does
        // every other row in this schema. The filtered index on unread keeps the set small.
        //
        // Somebody else's notification about the same booking is untouched: the business owner and
        // the customer are both told when a job is confirmed, and the customer opening it says
        // nothing about whether the owner has seen theirs.
        var unread = await dbContext.Notifications
            .Where(n => n.UserId == userId
                && n.ReadAt == null
                && n.Target == request.Target
                && n.TargetId == request.TargetId)
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
