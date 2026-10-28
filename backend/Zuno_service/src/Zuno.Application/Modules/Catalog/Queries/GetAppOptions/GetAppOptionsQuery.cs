using MediatR;
using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Modules.Catalog.Queries.GetAppOptions;

/// <summary>The limits the app's forms enforce before a request is sent.</summary>
public record GetAppOptionsQuery : IRequest<AppOptionsDto>;
