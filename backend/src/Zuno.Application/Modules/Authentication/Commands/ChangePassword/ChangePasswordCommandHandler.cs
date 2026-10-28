using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Commands.ChangePassword;

public class ChangePasswordCommandHandler(
    ICurrentUserService currentUserService,
    IUserRepository userRepository,
    IPasswordHasher passwordHasher,
    IRefreshTokenRepository refreshTokenRepository,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<ChangePasswordCommand>
{
    public async Task Handle(ChangePasswordCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException("User", userId);

        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
        {
            throw new UnauthorizedAccessException("Current password is incorrect.");
        }

        user.PasswordHash = passwordHasher.Hash(request.NewPassword);

        // Every session ends with the old password, as a reset already does: otherwise someone who
        // stole a session keeps it after the owner changes the password to lock them out.
        foreach (var token in await refreshTokenRepository.GetActiveTokensForUserAsync(user.Id, cancellationToken))
        {
            token.RevokedAt = dateTimeProvider.UtcNow;
            token.ReasonRevoked = "PasswordChanged";
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
