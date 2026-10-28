using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceCategory;

public class SaveServiceCategoryCommandHandler(IApplicationDbContext dbContext)
    : IRequestHandler<SaveServiceCategoryCommand, AdminServiceCategoryDto>
{
    public async Task<AdminServiceCategoryDto> Handle(
        SaveServiceCategoryCommand request,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        var slug = CatalogSlug.From(name);

        if (slug.Length == 0)
        {
            throw new DomainException("That name has no letters or numbers in it. Try another.");
        }

        // Category slugs are unique across the whole catalogue, so the clash is checked here
        // rather than left to the database — a unique-index violation surfaces as a 500 with
        // nothing the app owner can act on.
        var slugTaken = await dbContext.ServiceCategories
            .AnyAsync(c => c.Slug == slug && c.Id != request.Id, cancellationToken);

        if (slugTaken)
        {
            throw new DomainException($"There is already a category called \"{name}\".");
        }

        ServiceCategory category;

        if (request.Id is { } id)
        {
            category = await dbContext.ServiceCategories
                .Include(c => c.SubCategories)
                .FirstOrDefaultAsync(c => c.Id == id, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(ServiceCategory), id);
        }
        else
        {
            category = new ServiceCategory();
            dbContext.ServiceCategories.Add(category);
        }

        category.Name = name;
        category.Slug = slug;
        category.Description = request.Description?.Trim();
        category.IconUrl = request.IconUrl?.Trim();
        category.IconName = request.IconName?.Trim();
        category.DisplayOrder = request.DisplayOrder;
        category.IsActive = request.IsActive;

        await dbContext.SaveChangesAsync(cancellationToken);

        var serviceCount = await dbContext.BusinessServices
            .CountAsync(s => s.ServiceCategoryId == category.Id, cancellationToken);

        return category.ToAdminDto(serviceCount);
    }
}
