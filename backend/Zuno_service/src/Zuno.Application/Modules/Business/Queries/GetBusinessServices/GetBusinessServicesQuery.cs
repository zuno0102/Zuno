using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessServices;

public class GetBusinessServicesQuery : IRequest<List<BusinessServiceDto>>;
