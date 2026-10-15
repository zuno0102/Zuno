using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Application.Modules.Authentication.DTOs;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Settings;

namespace Zuno.Application.Modules.Authentication.Commands.RefreshToken;

public class RefreshTokenCommandHandler(
    IRefreshTokenRepository refreshTokenRepository,
    IApplicationDbContext dbContext,
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    IOptions<JwtSettings> jwtSettings,
    RefreshTokenFactory refreshTokenFactory) : IRequestHandler<RefreshTokenCommand, AuthResponseDto>
{
    public async Task<AuthResponseDto> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        var tokenHash = jwtTokenService.HashToken(request.RefreshToken);
        var existingToken = await refreshTokenRepository.GetByTokenHashAsync(tokenHash, cancellationToken);

        if (existingToken is null)
        {
            throw new UnauthorizedAccessException("Invalid refresh token.");
        }

        if (existingToken.IsRevoked)
        {
            // Reuse of an already-rotated token indicates the token was stolen and replayed —
            // revoke the user's entire active chain and force a fresh login.
            await RevokeAllActiveTokensAsync(existingToken.UserId, request.IpAddress, cancellationToken);
            throw new UnauthorizedAccessException("Refresh token has already been used. All sessions have been revoked.");
        }

        if (existingToken.IsExpired)
        {
            throw new UnauthorizedAccessException("Refresh token has expired.");
        }

        var (newToken, rawNewToken) = refreshTokenFactory.Create(existingToken.UserId, request.IpAddress);
        refreshTokenRepository.Add(newToken);

        existingToken.RevokedAt = dateTimeProvider.UtcNow;
        existingToken.RevokedByIp = request.IpAddress;
        existingToken.ReasonRevoked = "Rotated";
        existingToken.ReplacedByTokenId = newToken.Id;

        await dbContext.SaveChangesAsync(cancellationToken);

        return new AuthResponseDto
        {
            AccessToken = jwtTokenService.GenerateAccessToken(existingToken.User),
            RefreshToken = rawNewToken,
            AccessTokenExpiresAt = dateTimeProvider.UtcNow.AddMinutes(jwtSettings.Value.AccessTokenExpiryMinutes),
            User = existingToken.User.ToDto(),
        };
    }

    private async Task RevokeAllActiveTokensAsync(Guid userId, string? ipAddress, CancellationToken cancellationToken)
    {
        var activeTokens = await refreshTokenRepository.GetActiveTokensForUserAsync(userId, cancellationToken);

        foreach (var token in activeTokens)
        {
            token.RevokedAt = dateTimeProvider.UtcNow;
            token.RevokedByIp = ipAddress;
            token.ReasonRevoked = "SecurityIncident:TokenReuseDetected";
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
