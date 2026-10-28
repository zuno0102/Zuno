using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;

public class SetBusinessServiceVideoCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<SetBusinessServiceVideoCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(SetBusinessServiceVideoCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var service = await businessServiceRepository.GetByIdAsync(request.ServiceId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.ServiceId);

        if (service.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This service does not belong to your business.");
        }

        // Written only now — see SetBusinessServiceImageCommandHandler for what the old order let
        // one business do to another's files.
        var url = await fileStorageService.SaveServiceVideoAsync(
            service.Id, request.Content, request.FileExtension, cancellationToken);

        var existing = service.Media.FirstOrDefault(m => m.MediaType == ServiceMediaType.Video);

        if (existing != null)
        {
            existing.Url = url;
        }
        else
        {
            // Added directly on the DbSet — see the comment in SetBusinessServiceImageCommandHandler
            // for why service.Media.Add(...) alone isn't enough for a brand-new child entity.
            var media = new BusinessServiceMedia
            {
                BusinessServiceId = service.Id,
                MediaType = ServiceMediaType.Video,
                SortOrder = 0,
                Url = url,
            };
            dbContext.BusinessServiceMedia.Add(media);
            service.Media.Add(media);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
