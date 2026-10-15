using MediatR;

namespace Zuno.Application.Modules.Business.Events;

/// <summary>
/// A business has asked a worker to join its permanent crew.
/// </summary>
/// <remarks>
/// Not about any one job — that is
/// <c>WorkerInvitedToHiringPostEvent</c>. This is the standing relationship, which is what lets a
/// business assign the worker to orders later without hiring them each time.
///
/// Carries the worker's user id as well as their email: the email is for the (still stubbed) mail
/// handler, and a notification is addressed to a user.
/// </remarks>
public class WorkerInvitedEvent(
    Guid businessWorkerId,
    Guid workerUserId,
    string? workerEmail,
    string businessName) : INotification
{
    public Guid BusinessWorkerId { get; } = businessWorkerId;

    public Guid WorkerUserId { get; } = workerUserId;

    public string? WorkerEmail { get; } = workerEmail;

    public string BusinessName { get; } = businessName;
}
