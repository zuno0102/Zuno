using Microsoft.EntityFrameworkCore;
using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessServiceVariant;

public class UpdateBusinessServiceVariantCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateBusinessServiceVariantCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(UpdateBusinessServiceVariantCommand request, CancellationToken cancellationToken)
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

        // The main category is the service's, never re-picked on the item, so anything outside
        // it would silently file this item under work the service does not offer. Loaded rather
        // than merely checked, so the response carries the name and not just the id.
        ServiceSubCategory? subCategory = null;
        if (request.ServiceSubCategoryId is { } subCategoryId)
        {
            subCategory = await dbContext.ServiceSubCategories.FirstOrDefaultAsync(
                s => s.Id == subCategoryId && s.ServiceCategoryId == service.ServiceCategoryId,
                cancellationToken)
                ?? throw new DomainException(
                    "That sub-category is not part of this service's category. Pick one from the list.");
        }

        var variant = service.Variants.FirstOrDefault(v => v.Id == request.VariantId)
            ?? throw new EntityNotFoundException(nameof(BusinessServiceVariant), request.VariantId);

        variant.Name = request.Name;
        variant.Description = request.Description;
        variant.PriceType = Enum.Parse<PriceType>(request.PriceType, ignoreCase: true);
        variant.Price = request.Price;
        variant.ServiceSubCategoryId = subCategory?.Id;
        variant.ServiceSubCategory = subCategory;
        variant.EstimatedDurationMinutes = request.EstimatedDurationMinutes;
        variant.IsActive = request.IsActive;

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
