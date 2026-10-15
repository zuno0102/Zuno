using MediatR;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Authentication.Commands.RevokeToken;

public class RevokeTokenCommandHandler(
    IRefreshTokenRepository refreshTokenRepository,
    IApplicationDbContext dbContext,
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    ICurrentUserService currentUserService) : IRequestHandler<RevokeTokenCommand>
{
    public async Task Handle(RevokeTokenCommand request, CancellationToken cancellationToken)
    {
        var tokenHash = jwtTokenService.HashToken(request.RefreshToken);
        var token = await refreshTokenRepository.GetByTokenHashAsync(tokenHash, cancellationToken);

        if (token is null || token.UserId != currentUserService.UserId)
        {
            throw new UnauthorizedAccessException("Invalid refresh token.");
        }

        if (!token.IsActive)
        {
            return;
        }

        token.RevokedAt = dateTimeProvider.UtcNow;
        token.RevokedByIp = request.IpAddress;
        token.ReasonRevoked = "UserLogout";

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
