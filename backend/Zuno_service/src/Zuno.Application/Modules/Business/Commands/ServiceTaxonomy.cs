using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands;

/// <summary>
/// Reading the category and the trade under it as one answer rather than two.
/// </summary>
public static class ServiceTaxonomy
{
    /// <summary>
    /// Resolves the chosen sub-category and refuses one that does not sit under [categoryId].
    /// </summary>
    /// <remarks>
    /// The two ids arrive from the client as separate fields, so nothing about the request itself
    /// guarantees they belong together. A form that filters the second list by the first is the
    /// happy path, not a rule — change the category after choosing a trade, or send the pair
    /// straight to the API, and the service would be filed under "Plumbing · Bedroom cleaning"
    /// with no complaint from the foreign key, which only asks that the row exists.
    ///
    /// Returns null for a null id: the trade is optional, and every service made before it
    /// existed has none.
    /// </remarks>
    public static async Task<ServiceSubCategory?> ResolveSubCategoryAsync(
        IApplicationDbContext dbContext,
        Guid categoryId,
        Guid? subCategoryId,
        CancellationToken cancellationToken)
    {
        if (subCategoryId is not { } id)
        {
            return null;
        }

        var subCategory = await dbContext.ServiceSubCategories
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken)
            ?? throw new DomainException("That kind of work is no longer listed. Pick another.");

        if (subCategory.ServiceCategoryId != categoryId)
        {
            throw new DomainException(
                $"\"{subCategory.Name}\" does not belong to the category you chose. " +
                "Pick a kind of work from that category.");
        }

        return subCategory;
    }
}
