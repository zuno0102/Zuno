using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IJwtTokenService
{
    string GenerateAccessToken(User user);

    string GenerateRefreshToken();

    string HashToken(string rawToken);

    /// <summary>
    /// Generates a short-lived, signed, single-purpose token used to authorize a password reset —
    /// stateless (no DB row) but verifiable and tamper-proof via the same JWT signing key.
    /// </summary>
    string GeneratePasswordResetToken(Guid userId);

    /// <summary>
    /// Validates a password-reset token and returns the embedded UserId, or null if invalid/expired.
    /// </summary>
    Guid? ValidatePasswordResetToken(string token);
}
