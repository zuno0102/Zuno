using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceSubCategory;

public class SaveServiceSubCategoryCommandHandler(IApplicationDbContext dbContext)
    : IRequestHandler<SaveServiceSubCategoryCommand, AdminServiceSubCategoryDto>
{
    public async Task<AdminServiceSubCategoryDto> Handle(
        SaveServiceSubCategoryCommand request,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        var slug = CatalogSlug.From(name);

        if (slug.Length == 0)
        {
            throw new DomainException("That name has no letters or numbers in it. Try another.");
        }

        var categoryExists = await dbContext.ServiceCategories
            .AnyAsync(c => c.Id == request.ServiceCategoryId, cancellationToken);

        if (!categoryExists)
        {
            throw new EntityNotFoundException(nameof(ServiceCategory), request.ServiceCategoryId);
        }

        ServiceSubCategory? existing = null;

        if (request.Id is { } id)
        {
            existing = await dbContext.ServiceSubCategories
                .FirstOrDefaultAsync(s => s.Id == id, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(ServiceSubCategory), id);

            // Refused rather than silently ignored. Items already priced under this sub-category
            // belong to services in the original category; moving it would leave them tagged with
            // a kind of work their own service does not offer.
            if (existing.ServiceCategoryId != request.ServiceCategoryId)
            {
                throw new DomainException(
                    "A sub-category cannot be moved to another category. Hide this one and add it "
                    + "under the category you want.");
            }
        }

        // Uniqueness is per category, not global: "water tank cleaning" legitimately sits under
        // both Plumbing and Cleaning, and the database index is scoped the same way.
        var slugTaken = await dbContext.ServiceSubCategories.AnyAsync(
            s => s.ServiceCategoryId == request.ServiceCategoryId
                && s.Slug == slug
                && s.Id != request.Id,
            cancellationToken);

        if (slugTaken)
        {
            throw new DomainException(
                $"That category already has a sub-category called \"{name}\".");
        }

        // Nothing is added to the context until every check has passed, so a refused save never
        // leaves a half-built row tracked behind it.
        var subCategory = existing;

        if (subCategory is null)
        {
            subCategory = new ServiceSubCategory { ServiceCategoryId = request.ServiceCategoryId };
            dbContext.ServiceSubCategories.Add(subCategory);
        }

        subCategory.Name = name;
        subCategory.Slug = slug;
        subCategory.DisplayOrder = request.DisplayOrder;
        subCategory.IsActive = request.IsActive;

        await dbContext.SaveChangesAsync(cancellationToken);

        return subCategory.ToAdminDto();
    }
}
