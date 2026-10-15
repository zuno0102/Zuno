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
        var userId = jwtTokenService.ValidatePasswordResetToken(request.Token)
            ?? throw new UnauthorizedAccessException("Invalid or expired password reset token.");

        var user = await userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException("User", userId);

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
