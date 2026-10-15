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

    public string GeneratePasswordResetToken(Guid userId)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(PasswordResetPurposeClaim, PasswordResetPurposeValue),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        var token = CreateToken(claims, PasswordResetTokenExpiry);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public Guid? ValidatePasswordResetToken(string token)
    {
        var validationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = _settings.Issuer,
            ValidateAudience = true,
            ValidAudience = _settings.Audience,
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

            return Guid.TryParse(subject, out var userId) ? userId : null;
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

    private JwtSecurityToken CreateToken(List<Claim> claims, TimeSpan expiry)
    {
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.SigningKey));
        var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        // Taken from the clock the rest of the application uses rather than DateTime.UtcNow, so
        // that how long a token lasts can actually be tested. With the system clock hard-coded
        // here, the only way to see a token expire was to wait for it, so nothing ever did —
        // "expires in 15 minutes" was a setting nobody had checked was honoured.
        return new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            expires: dateTimeProvider.UtcNow.UtcDateTime.Add(expiry),
            signingCredentials: credentials);
    }
}
