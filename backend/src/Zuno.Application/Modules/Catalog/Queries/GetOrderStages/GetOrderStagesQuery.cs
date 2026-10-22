using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetOrderStages;

public class GetOrderStagesQuery : IRequest<List<OrderStageDto>>;
