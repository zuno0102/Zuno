using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Authentication.Commands.Login;

public class LoginCommandHandler(
    IUserRepository userRepository,
    IRefreshTokenRepository refreshTokenRepository,
    IApplicationDbContext dbContext,
    IPasswordHasher passwordHasher,
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    IOptions<JwtSettings> jwtSettings,
    RefreshTokenFactory refreshTokenFactory) : IRequestHandler<LoginCommand, AuthResponseDto>
{
    private const short MaxFailedLoginAttempts = 5;
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);

    public async Task<AuthResponseDto> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var user = await userRepository.GetByEmailOrPhoneAsync(request.EmailOrPhone, cancellationToken);

        if (user is null || !user.IsActive)
        {
            throw new UnauthorizedAccessException("Invalid credentials.");
        }

        if (user.IsLockedOut)
        {
            throw new UnauthorizedAccessException(
                $"Account is temporarily locked. Try again after {user.LockoutEndDate:u}.");
        }

        if (!passwordHasher.Verify(request.Password, user.PasswordHash))
        {
            await RegisterFailedLoginAttemptAsync(user, cancellationToken);
            throw new UnauthorizedAccessException("Invalid credentials.");
        }

        user.FailedLoginAttempts = 0;
        user.LockoutEndDate = null;
        user.LastLoginDate = dateTimeProvider.UtcNow;

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
