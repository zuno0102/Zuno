using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessService;

public class CreateBusinessServiceCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IApplicationDbContext dbContext) : IRequestHandler<CreateBusinessServiceCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(CreateBusinessServiceCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        var category = await dbContext.ServiceCategories
            .FirstOrDefaultAsync(c => c.Id == request.ServiceCategoryId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(ServiceCategory), request.ServiceCategoryId);

        var subCategory = await ServiceTaxonomy.ResolveSubCategoryAsync(
            dbContext, category.Id, request.ServiceSubCategoryId, cancellationToken);

        var districts = await dbContext.Districts
            .Include(d => d.State)
            .Where(d => request.DistrictIds.Contains(d.Id))
            .ToListAsync(cancellationToken);

        var service = new BusinessService
        {
            BusinessOwnerProfileId = businessProfile.Id,
            ServiceCategoryId = category.Id,
            ServiceCategory = category,
            ServiceSubCategoryId = subCategory?.Id,
            ServiceSubCategory = subCategory,
            Name = request.Name,
            ItemName = request.ItemName,
            Description = request.Description,
            PriceType = Enum.Parse<PriceType>(request.PriceType, ignoreCase: true),
            Price = request.Price,
            EstimatedDurationMinutes = request.EstimatedDurationMinutes,
            RequiredWorkerCount = request.RequiredWorkerCount,
            TargetDistricts = districts
                .Select(d => new BusinessServiceDistrict { DistrictId = d.Id, District = d })
                .ToList(),
        };

        businessServiceRepository.Add(service);
        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
