using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Services;

public class JwtTokenService(
    IOptions<JwtSettings> jwtSettings,
    IDateTimeProvider dateTimeProvider) : IJwtTokenService
{
    private const string PasswordResetPurposeClaim = "purpose";
    private const string PasswordResetPurposeValue = "password_reset";
    private static readonly TimeSpan PasswordResetTokenExpiry = TimeSpan.FromMinutes(30);
    private const string PasswordStampClaim = "pwd";

    /// <summary>
    /// Reset tokens are issued for their own audience, so the bearer handler — which accepts only the
    /// sign-in audience — can never take one as a sign-in token on an [Authorize] endpoint.
    /// </summary>
    private string PasswordResetAudience => _settings.Audience + ".password-reset";

    private readonly JwtSettings _settings = jwtSettings.Value;

    public string GenerateAccessToken(User user)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Role, user.Role.Name),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        if (!string.IsNullOrWhiteSpace(user.Email))
        {
            claims.Add(new Claim(JwtRegisteredClaimNames.Email, user.Email));
        }

        var token = CreateToken(claims, TimeSpan.FromMinutes(_settings.AccessTokenExpiryMinutes));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes = RandomNumberGenerator.GetBytes(32);
        return Convert.ToBase64String(randomBytes)
            .Replace('+', '-')
            .Replace('/', '_')
            .TrimEnd('=');
    }

    public string HashToken(string rawToken)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));
        return Convert.ToHexString(bytes);
    }

    public string GeneratePasswordResetToken(Guid userId, string currentPasswordHash)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(PasswordResetPurposeClaim, PasswordResetPurposeValue),
            new(PasswordStampClaim, PasswordStamp(currentPasswordHash)),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        var token = CreateToken(claims, PasswordResetTokenExpiry, PasswordResetAudience);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public PasswordResetClaims? ValidatePasswordResetToken(string token)
    {
        var validationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = _settings.Issuer,
            ValidateAudience = true,
            ValidAudience = PasswordResetAudience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
        };

        try
        {
            var principal = new JwtSecurityTokenHandler().ValidateToken(token, validationParameters, out _);

            var purpose = principal.FindFirstValue(PasswordResetPurposeClaim);
            if (purpose != PasswordResetPurposeValue)
            {
                return null;
            }

            // Read under both names. Validation applies the inbound claim-type map, which renames
            // "sub" to ClaimTypes.NameIdentifier, so asking only for "sub" found nothing — every
            // valid reset token was rejected as invalid and nobody could ever finish a reset.
            var subject = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
                ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);

            var stamp = principal.FindFirstValue(PasswordStampClaim);
            return Guid.TryParse(subject, out var userId) && !string.IsNullOrEmpty(stamp)
                ? new PasswordResetClaims(userId, stamp)
                : null;
        }
        catch (Exception exception) when (exception is SecurityTokenException or ArgumentException)
        {
            // ArgumentException as well as the token exceptions: a truncated or mangled token —
            // an email client wrapping a reset link, say — is rejected by the handler with
            // ArgumentException rather than a token exception, and that escaped as a 500 instead
            // of the "invalid or expired link" this returns.
            return null;
        }
    }

    /// <inheritdoc />
    /// <remarks>
    /// A keyed hash, not the password hash itself: the token is readable by whoever holds it, and must
    /// say nothing about the password. It changes whenever the password does, which is what makes a
    /// reset link work once.
    /// </remarks>
    public string PasswordStamp(string passwordHash)
    {
        var mac = HMACSHA256.HashData(
            Encoding.UTF8.GetBytes(_settings.SigningKey), Encoding.UTF8.GetBytes(passwordHash));
        return Convert.ToBase64String(mac, 0, 16).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }

    private JwtSecurityToken CreateToken(List<Claim> claims, TimeSpan expiry, string? audience = null)
    {
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.SigningKey));
        var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        // Taken from the clock the rest of the application uses rather than DateTime.UtcNow, so
        // that how long a token lasts can actually be tested. With the system clock hard-coded
        // here, the only way to see a token expire was to wait for it, so nothing ever did —
        // "expires in 15 minutes" was a setting nobody had checked was honoured.
        return new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: audience ?? _settings.Audience,
            claims: claims,
            expires: dateTimeProvider.UtcNow.UtcDateTime.Add(expiry),
            signingCredentials: credentials);
    }
}
