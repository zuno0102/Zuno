namespace Zuno.Application.Common.Interfaces;

public interface ICurrentUserService
{
    Guid? UserId { get; }

    string? Role { get; }

    string? IpAddress { get; }

    bool IsAuthenticated { get; }
}
