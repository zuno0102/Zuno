using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Queries.GetCurrentUser;

public class GetCurrentUserQueryHandler(
    ICurrentUserService currentUserService,
    IUserRepository userRepository) : IRequestHandler<GetCurrentUserQuery, UserDto>
{
    public async Task<UserDto> Handle(GetCurrentUserQuery request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException("User", userId);

        return user.ToDto();
    }
}
