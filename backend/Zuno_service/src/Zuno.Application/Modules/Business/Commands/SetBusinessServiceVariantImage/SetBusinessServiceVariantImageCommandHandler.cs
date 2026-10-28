using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantImage;

public class SetBusinessServiceVariantImageCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<SetBusinessServiceVariantImageCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(SetBusinessServiceVariantImageCommand request, CancellationToken cancellationToken)
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

        // Written only now, once both the service and the package are known to be the caller's —
        // see SetBusinessServiceImageCommandHandler for what the old order let one business do to
        // another's files.
        var url = await fileStorageService.SaveServiceVariantImageAsync(
            service.Id, variant.Id, request.SlotIndex, request.Content, request.FileExtension, cancellationToken);

        var existing = variant.Media.FirstOrDefault(
            m => m.MediaType == ServiceMediaType.Image && m.SortOrder == request.SlotIndex);

        if (existing != null)
        {
            existing.Url = url;
        }
        else
        {
            // Added directly on the DbSet — see the comment in SetBusinessServiceImageCommandHandler
            // for why variant.Media.Add(...) alone isn't enough for a brand-new child entity.
            var media = new BusinessServiceMedia
            {
                BusinessServiceVariantId = variant.Id,
                MediaType = ServiceMediaType.Image,
                SortOrder = (short)request.SlotIndex,
                Url = url,
            };
            dbContext.BusinessServiceMedia.Add(media);
            variant.Media.Add(media);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
