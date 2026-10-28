using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class RefreshToken : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public string TokenHash { get; set; } = string.Empty;

    public DateTimeOffset ExpiresAt { get; set; }

    public string? CreatedByIp { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }

    public string? RevokedByIp { get; set; }

    public Guid? ReplacedByTokenId { get; set; }

    public RefreshToken? ReplacedByToken { get; set; }

    public string? ReasonRevoked { get; set; }

    public bool IsExpired => DateTimeOffset.UtcNow >= ExpiresAt;

    public bool IsRevoked => RevokedAt.HasValue;

    public bool IsActive => !IsRevoked && !IsExpired;
}
