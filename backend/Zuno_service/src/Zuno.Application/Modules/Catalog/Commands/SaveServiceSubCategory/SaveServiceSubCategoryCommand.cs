using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceSubCategory;

/// <summary>
/// Adds a narrower kind of work inside a category, or edits one that exists.
/// </summary>
/// <remarks>
/// A sub-category belongs to exactly one category and cannot be moved between them: businesses
/// have priced items under it, and those items inherit the main category from their parent
/// service. Moving it would silently put an item under a category its service does not belong to.
///
/// Like categories, these are retired by hiding rather than deleting — the foreign key is
/// deliberately set to refuse deletion so that retiring a kind of work never removes the items
/// businesses have priced under it.
/// </remarks>
public class SaveServiceSubCategoryCommand : IRequest<AdminServiceSubCategoryDto>
{
    /// <summary>Null to add a new sub-category; otherwise the one being edited.</summary>
    public Guid? Id { get; set; }

    /// <summary>Which category it sits under. Fixed once created.</summary>
    public Guid ServiceCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
