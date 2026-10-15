using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;

public class RemoveBusinessServiceImageCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<RemoveBusinessServiceImageCommand>
{
    public async Task Handle(RemoveBusinessServiceImageCommand request, CancellationToken cancellationToken)
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

        var existing = service.Media.FirstOrDefault(
            m => m.MediaType == ServiceMediaType.Image && m.SortOrder == request.SlotIndex);

        if (existing == null)
        {
            return;
        }

        // Deleted through the DbSet, not by taking it out of service.Media. Removing it from the
        // collection only severs the relationship, and EF answers that by setting the row's
        // business_service_id to null — which the table refuses, because it requires exactly one
        // of its two owner columns to be set. The result was a 500 and a picture that stayed put.
        dbContext.BusinessServiceMedia.Remove(existing);
        await dbContext.SaveChangesAsync(cancellationToken);
        fileStorageService.DeleteFile(existing.Url);
    }
}
