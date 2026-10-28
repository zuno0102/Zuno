using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Commands.SetServiceCategoryIcon;

/// <summary>
/// Records the icon image a category has just had uploaded.
/// </summary>
/// <remarks>
/// Separate from <c>SaveServiceCategoryCommand</c>, which carries the whole row: an upload changes
/// exactly one field, and routing it through the full save would make a half-filled form able to
/// blank a category's name as a side effect of changing its picture.
/// </remarks>
public class SetServiceCategoryIconCommand : IRequest<AdminServiceCategoryDto>
{
    public Guid Id { get; set; }

    /// <summary>The root-relative URL the storage service returned.</summary>
    public string IconUrl { get; set; } = string.Empty;
}
