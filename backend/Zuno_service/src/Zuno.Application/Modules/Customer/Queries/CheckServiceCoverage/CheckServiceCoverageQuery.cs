using MediatR;

namespace Zuno.Application.Modules.Customer.Queries.CheckServiceCoverage;

/// <summary>Whether a service is offered at a pinned location, asked before the customer books.</summary>
public record CheckServiceCoverageQuery(Guid ServiceId, decimal Latitude, decimal Longitude)
    : IRequest<ServiceCoverageDto>;

/// <summary>The answer, with the districts the service is offered in so the app can name them.</summary>
public record ServiceCoverageDto(bool IsAvailable, IReadOnlyList<string> ServedDistricts);
