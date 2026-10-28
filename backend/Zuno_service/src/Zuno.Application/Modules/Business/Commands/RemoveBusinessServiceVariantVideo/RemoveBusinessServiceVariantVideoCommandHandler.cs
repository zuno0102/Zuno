using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantVideo;

public class RemoveBusinessServiceVariantVideoCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<RemoveBusinessServiceVariantVideoCommand>
{
    public async Task Handle(RemoveBusinessServiceVariantVideoCommand request, CancellationToken cancellationToken)
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

        var variant = service.Variants.FirstOrDefault(v => v.Id == request.VariantId)
            ?? throw new EntityNotFoundException(nameof(BusinessServiceVariant), request.VariantId);

        var existing = variant.Media.FirstOrDefault(m => m.MediaType == ServiceMediaType.Video);

        if (existing == null)
        {
            return;
        }

        // Deleted through the DbSet — see RemoveBusinessServiceImageCommandHandler for why taking
        // it out of the collection instead produced a 500 and left the video in place.
        dbContext.BusinessServiceMedia.Remove(existing);
        await dbContext.SaveChangesAsync(cancellationToken);
        fileStorageService.DeleteFile(existing.Url);
    }
}
