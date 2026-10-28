using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Authentication.DTOs;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Authentication.Commands.UpdateMyAccount;

public class UpdateMyAccountCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateMyAccountCommand, UserDto>
{
    public async Task<UserDto> Handle(
        UpdateMyAccountCommand request,
        CancellationToken cancellationToken)
    {
        // The account edited is always the one in the token. There is no id in the command for a
        // caller to swap for somebody else's.
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await dbContext.Users
            // Included because the response maps through UserDto, which reads Role.Name — without it
            // the save succeeds and then the reply throws, which is the worst shape of failure: the
            // change is made and the caller is told it was not.
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new EntityNotFoundException("User", userId);

        var phoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber)
            ? null
            : request.PhoneNumber.Trim();

        // A phone number is one of the two ways to sign in, so two accounts sharing one would make
        // that login ambiguous. Checked here as well as in the validator because the validator cannot
        // see the signed-in user, and "already taken" must not fire on your own number.
        if (phoneNumber is not null)
        {
            var takenByAnother = await dbContext.Users
                .AnyAsync(
                    u => u.PhoneNumber == phoneNumber && u.Id != userId && !u.IsDeleted,
                    cancellationToken);

            if (takenByAnother)
            {
                throw new DomainException("That phone number is already in use.");
            }
        }

        user.FirstName = request.FirstName.Trim();
        user.LastName = request.LastName.Trim();

        // Changing the number unverifies it: the old confirmation was for a different number.
        if (user.PhoneNumber != phoneNumber)
        {
            user.PhoneNumber = phoneNumber;
            user.PhoneNumberConfirmed = false;
        }

        user.ModifiedDate = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return user.ToDto();
    }
}
