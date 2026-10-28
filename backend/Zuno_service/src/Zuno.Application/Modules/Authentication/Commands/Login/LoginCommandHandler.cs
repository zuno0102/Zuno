using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.Common;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Authentication.Commands.Login;

public class LoginCommandHandler(
    IUserRepository userRepository,
    IRefreshTokenRepository refreshTokenRepository,
    IApplicationDbContext dbContext,
    IPasswordHasher passwordHasher,
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    IOptions<JwtSettings> jwtSettings,
    BusinessApproval businessApproval,
    RefreshTokenFactory refreshTokenFactory) : IRequestHandler<LoginCommand, AuthResponseDto>
{
    private const short MaxFailedLoginAttempts = 5;
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);

    /// <summary>
    /// A real hash of a random password, checked against when no account matches, so a login for an
    /// address nobody uses takes as long as one with a wrong password. Without it the missing hash
    /// check made unknown accounts answer measurably faster, which told anyone timing the replies
    /// which emails and phone numbers are registered.
    /// </summary>
    private static string? _absentAccountHash;

    public async Task<AuthResponseDto> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var user = await userRepository.GetByEmailOrPhoneAsync(request.EmailOrPhone, cancellationToken);

        if (user is null || !user.IsActive)
        {
            _absentAccountHash ??= passwordHasher.Hash(Guid.NewGuid().ToString());
            passwordHasher.Verify(request.Password, _absentAccountHash);
            throw new UnauthorizedAccessException("Invalid credentials.");
        }

        if (user.IsLockedOut)
        {
            // Says neither that the account exists nor exactly when it opens again.
            throw new UnauthorizedAccessException("Too many attempts. Try again in a few minutes.");
        }

        if (!passwordHasher.Verify(request.Password, user.PasswordHash))
        {
            await RegisterFailedLoginAttemptAsync(user, cancellationToken);
            throw new UnauthorizedAccessException("Invalid credentials.");
        }

        user.FailedLoginAttempts = 0;
        user.LockoutEndDate = null;
        user.LastLoginDate = dateTimeProvider.UtcNow;

        // A business that registered while auto-approval was off, or that did not pass the check then,
        // gets another chance each time it signs in — approved only if auto-approval is now on and it
        // passes. With auto-approval off this does nothing: an admin decides.
        var pendingBusiness = businessApproval.IsAutoApproveOn
            ? await dbContext.BusinessOwnerProfiles
                .FirstOrDefaultAsync(
                    p => p.UserId == user.Id && p.VerificationStatus == VerificationStatus.Pending,
                    cancellationToken)
            : null;
        if (pendingBusiness is not null)
        {
            await businessApproval.TryAutoApproveAsync(pendingBusiness, cancellationToken);
        }

        var (refreshToken, rawRefreshToken) = refreshTokenFactory.Create(user.Id, request.IpAddress);
        refreshTokenRepository.Add(refreshToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        return new AuthResponseDto
        {
            AccessToken = jwtTokenService.GenerateAccessToken(user),
            RefreshToken = rawRefreshToken,
            AccessTokenExpiresAt = dateTimeProvider.UtcNow.AddMinutes(jwtSettings.Value.AccessTokenExpiryMinutes),
            User = user.ToDto(),
        };
    }

    private async Task RegisterFailedLoginAttemptAsync(User user, CancellationToken cancellationToken)
    {
        user.FailedLoginAttempts++;

        if (user.FailedLoginAttempts >= MaxFailedLoginAttempts)
        {
            user.LockoutEndDate = dateTimeProvider.UtcNow.Add(LockoutDuration);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
