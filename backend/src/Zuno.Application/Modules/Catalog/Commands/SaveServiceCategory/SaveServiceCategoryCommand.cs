using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Commands.SaveServiceCategory;

/// <summary>
/// Adds a main category, or edits one that exists.
/// </summary>
/// <remarks>
/// Until now the catalogue could only grow by hand-writing a migration, which is why "Catering"
/// and "Decorations" are missing while a developer is the only one who can add them. This is the
/// same act, done by the app owner.
///
/// There is deliberately no delete. Businesses have real services priced under these rows and the
/// database refuses to remove a category out from under them — so retiring one means
/// <see cref="IsActive"/> false, which takes it out of the pickers and leaves every existing
/// service working exactly as before.
/// </remarks>
public class SaveServiceCategoryCommand : IRequest<AdminServiceCategoryDto>
{
    /// <summary>Null to add a new category; otherwise the one being edited.</summary>
    public Guid? Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? IconUrl { get; set; }

    /// <summary>Which built-in icon the apps draw. Null leaves the client to guess from the name.</summary>
    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}
