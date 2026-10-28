using System.Security.Cryptography;
using System.Text;
using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Commands.ResetPassword;

public class ResetPasswordCommandHandler(
    IJwtTokenService jwtTokenService,
    IUserRepository userRepository,
    IRefreshTokenRepository refreshTokenRepository,
    IPasswordHasher passwordHasher,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<ResetPasswordCommand>
{
    public async Task Handle(ResetPasswordCommand request, CancellationToken cancellationToken)
    {
        var claims = jwtTokenService.ValidatePasswordResetToken(request.Token)
            ?? throw new UnauthorizedAccessException("Invalid or expired password reset token.");

        var user = await userRepository.GetByIdAsync(claims.UserId, cancellationToken)
            ?? throw new EntityNotFoundException("User", claims.UserId);

        // One use only: the token was issued against the password the account had then. Once it has
        // been used — or the password changed any other way — the stamp no longer matches, so a link
        // that leaked from an inbox or a log cannot be replayed.
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(jwtTokenService.PasswordStamp(user.PasswordHash)),
                Encoding.UTF8.GetBytes(claims.PasswordStamp)))
        {
            throw new UnauthorizedAccessException("Invalid or expired password reset token.");
        }

        user.PasswordHash = passwordHasher.Hash(request.NewPassword);

        // A password reset invalidates all existing sessions.
        var activeTokens = await refreshTokenRepository.GetActiveTokensForUserAsync(user.Id, cancellationToken);
        foreach (var token in activeTokens)
        {
            token.RevokedAt = dateTimeProvider.UtcNow;
            token.ReasonRevoked = "PasswordReset";
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
