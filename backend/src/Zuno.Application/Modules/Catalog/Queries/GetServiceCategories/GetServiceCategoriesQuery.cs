using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetServiceCategories;

public class GetServiceCategoriesQuery : IRequest<List<ServiceCategoryDto>>;
