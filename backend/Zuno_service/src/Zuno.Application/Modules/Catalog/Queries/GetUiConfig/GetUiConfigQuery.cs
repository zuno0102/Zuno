using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetUiConfig;

/// <summary>The apps' labels and colours.</summary>
public record GetUiConfigQuery : IRequest<UiConfigDto>;

/// <summary>Served from memory: no database round trip per request.</summary>
public class GetUiConfigQueryHandler(IUiConfigStore store) : IRequestHandler<GetUiConfigQuery, UiConfigDto>
{
    public Task<UiConfigDto> Handle(GetUiConfigQuery request, CancellationToken cancellationToken) =>
        Task.FromResult(store.Current);
}
