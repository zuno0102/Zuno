using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessLogo;

public class SetBusinessLogoCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<SetBusinessLogoCommand, BusinessProfileDto>
{
    public async Task<BusinessProfileDto> Handle(SetBusinessLogoCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var previousUrl = profile.LogoUrl;
        profile.LogoUrl = request.Url;

        await dbContext.SaveChangesAsync(cancellationToken);

        // Deleted only after the row is safely saved, and only when it is genuinely a different
        // file. Replacing a JPEG with a JPEG writes over the same name, so deleting afterwards
        // would remove the picture that was just uploaded.
        if (previousUrl is { Length: > 0 } && previousUrl != request.Url)
        {
            fileStorageService.DeleteFile(previousUrl);
        }

        return profile.ToDto();
    }
}
