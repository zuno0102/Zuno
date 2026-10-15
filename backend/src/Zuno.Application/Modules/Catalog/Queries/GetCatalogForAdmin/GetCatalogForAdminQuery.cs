using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetCatalogForAdmin;

/// <summary>
/// The whole catalogue, hidden rows included, for the app owner to manage.
/// </summary>
/// <remarks>
/// The public <c>GetServiceCategoriesQuery</c> deliberately shows only active rows. This one must
/// show everything, because a hidden category is invisible anywhere else — this screen is the only
/// place it can be brought back.
/// </remarks>
public record GetCatalogForAdminQuery : IRequest<List<AdminServiceCategoryDto>>;
