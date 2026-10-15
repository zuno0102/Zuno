using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.DeleteBusinessServiceVariant;

public class DeleteBusinessServiceVariantCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IFileStorageService fileStorageService,
    IApplicationDbContext dbContext) : IRequestHandler<DeleteBusinessServiceVariantCommand>
{
    public async Task Handle(DeleteBusinessServiceVariantCommand request, CancellationToken cancellationToken)
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

        var mediaUrls = variant.Media.Select(m => m.Url).ToList();

        service.Variants.Remove(variant);
        await dbContext.SaveChangesAsync(cancellationToken);

        foreach (var url in mediaUrls)
        {
            fileStorageService.DeleteFile(url);
        }
    }
}
