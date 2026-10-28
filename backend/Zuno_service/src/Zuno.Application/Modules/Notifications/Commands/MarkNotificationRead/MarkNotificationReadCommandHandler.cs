using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Notifications.Commands.MarkNotificationRead;

public class MarkNotificationReadCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<MarkNotificationReadCommand, Unit>
{
    public async Task<Unit> Handle(
        MarkNotificationReadCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Matched on the owner as well as the id, so somebody else's notification is simply not
        // found rather than refused — a refusal would confirm it exists.
        var notification = await dbContext.Notifications
            .FirstOrDefaultAsync(
                n => n.Id == request.NotificationId && n.UserId == userId,
                cancellationToken)
            ?? throw new EntityNotFoundException("Notification", request.NotificationId);

        if (notification.ReadAt is not null)
        {
            // Already read. Keep the first time it was opened rather than moving the mark forward.
            return Unit.Value;
        }

        notification.ReadAt = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}
