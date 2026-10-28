using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Authentication.Common;

public class RefreshTokenFactory(
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    IOptions<JwtSettings> jwtSettings)
{
    public (RefreshToken Token, string RawToken) Create(Guid userId, string? ipAddress)
    {
        var rawToken = jwtTokenService.GenerateRefreshToken();

        var refreshToken = new RefreshToken
        {
            UserId = userId,
            TokenHash = jwtTokenService.HashToken(rawToken),
            ExpiresAt = dateTimeProvider.UtcNow.AddDays(jwtSettings.Value.RefreshTokenExpiryDays),
            CreatedByIp = ipAddress,
        };

        return (refreshToken, rawToken);
    }
}
