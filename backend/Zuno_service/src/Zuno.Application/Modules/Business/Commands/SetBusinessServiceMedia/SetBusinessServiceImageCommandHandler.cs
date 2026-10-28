using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;

public class SetBusinessServiceImageCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<SetBusinessServiceImageCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(SetBusinessServiceImageCommand request, CancellationToken cancellationToken)
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

        // Only now is anything written. Saving clears whatever occupies the slot, so doing it
        // before the check above let one business wipe another's picture by guessing a service id.
        var url = await fileStorageService.SaveServiceImageAsync(
            service.Id, request.SlotIndex, request.Content, request.FileExtension, cancellationToken);

        var existing = service.Media.FirstOrDefault(
            m => m.MediaType == ServiceMediaType.Image && m.SortOrder == request.SlotIndex);

        if (existing != null)
        {
            existing.Url = url;
        }
        else
        {
            // Added directly on the DbSet (not just service.Media.Add(...)): this entity's Guid
            // key is already non-empty (set by BaseEntity's property initializer) before EF ever
            // sees it, so discovering it only via navigation-collection fixup on an
            // already-tracked parent would make EF think it's an existing row being reattached
            // (EntityState.Modified) rather than a new one (EntityState.Added) — producing an
            // UPDATE for a row that doesn't exist yet, which fails with a concurrency exception.
            var media = new BusinessServiceMedia
            {
                BusinessServiceId = service.Id,
                MediaType = ServiceMediaType.Image,
                SortOrder = (short)request.SlotIndex,
                Url = url,
            };
            dbContext.BusinessServiceMedia.Add(media);
            service.Media.Add(media);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
