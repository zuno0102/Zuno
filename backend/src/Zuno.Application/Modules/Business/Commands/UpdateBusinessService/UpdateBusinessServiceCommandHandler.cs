using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessService;

public class UpdateBusinessServiceCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IApplicationDbContext dbContext) : IRequestHandler<UpdateBusinessServiceCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(UpdateBusinessServiceCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var service = await businessServiceRepository.GetByIdAsync(request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.Id);

        if (service.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This service does not belong to your business.");
        }

        if (service.ServiceCategoryId != request.ServiceCategoryId)
        {
            service.ServiceCategory = await dbContext.ServiceCategories
                .FirstOrDefaultAsync(c => c.Id == request.ServiceCategoryId, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(ServiceCategory), request.ServiceCategoryId);
            service.ServiceCategoryId = request.ServiceCategoryId;

            // Every item's sub-category belonged to the old category, so it would now say this
            // item is work the service no longer offers. Clearing is the honest answer — the
            // business re-tags each item from the new category's list.
            foreach (var variant in service.Variants)
            {
                variant.ServiceSubCategoryId = null;
            }
        }

        // Checked against the category being saved, not the one the service had, so moving a
        // service to another category and re-tagging it in the same save is accepted while the
        // old category's trade is not.
        var subCategory = await ServiceTaxonomy.ResolveSubCategoryAsync(
            dbContext, request.ServiceCategoryId, request.ServiceSubCategoryId, cancellationToken);

        service.ServiceSubCategoryId = subCategory?.Id;
        service.ServiceSubCategory = subCategory;

        service.Name = request.Name;
        service.ItemName = request.ItemName;
        service.Description = request.Description;
        service.PriceType = Enum.Parse<PriceType>(request.PriceType, ignoreCase: true);
        service.Price = request.Price;
        service.EstimatedDurationMinutes = request.EstimatedDurationMinutes;
        service.RequiredWorkerCount = request.RequiredWorkerCount;
        service.IsActive = request.IsActive;

        var requestedDistrictIds = request.DistrictIds.ToHashSet();
        var currentDistrictIds = service.TargetDistricts.Select(t => t.DistrictId).ToHashSet();

        foreach (var toRemove in service.TargetDistricts.Where(t => !requestedDistrictIds.Contains(t.DistrictId)).ToList())
        {
            service.TargetDistricts.Remove(toRemove);
        }

        var districtIdsToAdd = requestedDistrictIds.Where(id => !currentDistrictIds.Contains(id)).ToList();
        if (districtIdsToAdd.Count > 0)
        {
            var districtsToAdd = await dbContext.Districts
                .Include(d => d.State)
                .Where(d => districtIdsToAdd.Contains(d.Id))
                .ToListAsync(cancellationToken);

            // Added directly on the DbSet (not just service.TargetDistricts.Add(...)): this
            // entity's Guid key is already non-empty (BaseEntity's property initializer) before
            // EF ever sees it, so discovering it only via navigation-collection fixup on an
            // already-tracked parent would make EF treat it as an existing row being reattached
            // (EntityState.Modified) instead of a new one (EntityState.Added) — producing an
            // UPDATE for a row that doesn't exist yet, which fails with a concurrency exception.
            foreach (var district in districtsToAdd)
            {
                var link = new BusinessServiceDistrict { DistrictId = district.Id, District = district };
                dbContext.BusinessServiceDistricts.Add(link);
                service.TargetDistricts.Add(link);
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
