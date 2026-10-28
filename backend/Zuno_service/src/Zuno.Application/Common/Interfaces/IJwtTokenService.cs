using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IJwtTokenService
{
    string GenerateAccessToken(User user);

    string GenerateRefreshToken();

    string HashToken(string rawToken);

    /// <summary>
    /// Generates a short-lived, signed, single-purpose token used to authorize a password reset —
    /// stateless (no DB row) but verifiable and tamper-proof. It carries a stamp of the password it
    /// was issued against, so it stops working the moment that password changes: one use only.
    /// </summary>
    string GeneratePasswordResetToken(Guid userId, string currentPasswordHash);

    /// <summary>
    /// Validates a password-reset token's signature, purpose and expiry, or null if any fails. The
    /// caller must still compare <see cref="PasswordResetClaims.PasswordStamp"/> with
    /// <see cref="PasswordStamp"/> of the account's current password hash.
    /// </summary>
    PasswordResetClaims? ValidatePasswordResetToken(string token);

    /// <summary>A keyed fingerprint of a password hash, as embedded in reset tokens.</summary>
    string PasswordStamp(string passwordHash);
}

/// <summary>What a valid password-reset token says: whose account, and which password it was issued against.</summary>
public sealed record PasswordResetClaims(Guid UserId, string PasswordStamp);
