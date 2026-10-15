using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Commands.SetMyAccountPhoto;

public class SetMyAccountPhotoCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<SetMyAccountPhotoCommand, UserDto>
{
    public async Task<UserDto> Handle(
        SetMyAccountPhotoCommand request,
        CancellationToken cancellationToken)
    {
        // Always the account in the token. There is no id in the command for a caller to swap.
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await dbContext.Users
            // The response maps through UserDto, which reads Role.Name.
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new EntityNotFoundException("User", userId);

        user.ProfileImageUrl = request.Url;
        user.ModifiedDate = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return user.ToDto();
    }
}
