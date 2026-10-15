using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Common;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Application.Modules.Authentication.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Commands.Register;

public class RegisterUserCommandHandler(
    IApplicationDbContext dbContext,
    IUserRepository userRepository,
    IRefreshTokenRepository refreshTokenRepository,
    IPasswordHasher passwordHasher,
    IJwtTokenService jwtTokenService,
    IDateTimeProvider dateTimeProvider,
    IOptions<JwtSettings> jwtSettings,
    RefreshTokenFactory refreshTokenFactory,
    IPublisher publisher) : IRequestHandler<RegisterUserCommand, AuthResponseDto>
{
    public async Task<AuthResponseDto> Handle(RegisterUserCommand request, CancellationToken cancellationToken)
    {
        var role = await dbContext.Roles
            .FirstOrDefaultAsync(r => r.Name == request.Role, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(Role), request.Role);

        var user = new User
        {
            Email = request.Email,
            PhoneNumber = request.PhoneNumber,
            PasswordHash = passwordHasher.Hash(request.Password),
            FirstName = request.FirstName,
            LastName = request.LastName,
            RoleId = role.Id,
        };
        user.Role = role;

        CreateRoleProfile(user, request.Role);

        userRepository.Add(user);

        var (refreshToken, rawRefreshToken) = refreshTokenFactory.Create(user.Id, request.IpAddress);
        refreshTokenRepository.Add(refreshToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(new UserRegisteredEvent(user.Id, user.Email, user.FirstName), cancellationToken);

        return BuildAuthResponse(user, rawRefreshToken);
    }

    private static void CreateRoleProfile(User user, string roleName)
    {
        if (roleName == nameof(Domain.Enums.UserRoleType.Customer))
        {
            user.CustomerProfile = new CustomerProfile { UserId = user.Id };
        }
        else if (roleName == nameof(Domain.Enums.UserRoleType.BusinessOwner))
        {
            user.BusinessOwnerProfile = new BusinessOwnerProfile { UserId = user.Id, BusinessName = $"{user.FirstName} {user.LastName}" };
        }
        else if (roleName == nameof(Domain.Enums.UserRoleType.Worker))
        {
            user.WorkerProfile = new WorkerProfile { UserId = user.Id };
        }
    }

    private AuthResponseDto BuildAuthResponse(User user, string rawRefreshToken) => new()
    {
        AccessToken = jwtTokenService.GenerateAccessToken(user),
        RefreshToken = rawRefreshToken,
        AccessTokenExpiresAt = dateTimeProvider.UtcNow.AddMinutes(jwtSettings.Value.AccessTokenExpiryMinutes),
        User = user.ToDto(),
    };
}
