using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetStates;

public class GetStatesQuery : IRequest<List<StateDto>>;
