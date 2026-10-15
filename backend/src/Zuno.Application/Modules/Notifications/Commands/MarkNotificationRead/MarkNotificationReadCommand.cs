using MediatR;

namespace Zuno.Application.Modules.Notifications.Commands.MarkNotificationRead;

/// <summary>
/// Marks one notification read — what tapping a row does on the way to opening it.
/// </summary>
/// <remarks>
/// Idempotent, and deliberately so: the app fires this as it navigates, and a retry on a flaky
/// connection must not be an error the person sees instead of the screen they asked for.
/// </remarks>
public class MarkNotificationReadCommand : IRequest<Unit>
{
    public Guid NotificationId { get; set; }
}
