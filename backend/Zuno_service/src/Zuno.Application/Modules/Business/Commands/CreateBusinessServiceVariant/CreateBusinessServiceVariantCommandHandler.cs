using Microsoft.EntityFrameworkCore;
using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessServiceVariant;

public class CreateBusinessServiceVariantCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IApplicationDbContext dbContext) : IRequestHandler<CreateBusinessServiceVariantCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(CreateBusinessServiceVariantCommand request, CancellationToken cancellationToken)
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

        // Added directly on the DbSet (not just service.Variants.Add(...)): this entity's Guid
        // key is already non-empty (BaseEntity's property initializer) before EF ever sees it,
        // so discovering it only via navigation-collection fixup on an already-tracked parent
        // would make EF treat it as an existing row being reattached (EntityState.Modified)
        // instead of a new one (EntityState.Added) — producing an UPDATE for a row that doesn't
        // exist yet, which fails with a concurrency exception (hit this exact bug already this
        // session with BusinessServiceMedia/BusinessServiceDistrict).
        var variant = new BusinessServiceVariant
        {
            BusinessServiceId = service.Id,
            Name = request.Name,
            Description = request.Description,
            PriceType = Enum.Parse<PriceType>(request.PriceType, ignoreCase: true),
            Price = request.Price,
            ServiceSubCategoryId = subCategory?.Id,
            ServiceSubCategory = subCategory,
            EstimatedDurationMinutes = request.EstimatedDurationMinutes,
        };
        dbContext.BusinessServiceVariants.Add(variant);
        service.Variants.Add(variant);

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
