using MediatR;

namespace Zuno.Application.Modules.Authentication.Events;

public class UserRegisteredEvent(Guid userId, string? email, string firstName) : INotification
{
    public Guid UserId { get; } = userId;

    public string? Email { get; } = email;

    public string FirstName { get; } = firstName;
}
