using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessWorkers;

public class GetBusinessWorkersQuery : IRequest<List<BusinessWorkerDto>>;
