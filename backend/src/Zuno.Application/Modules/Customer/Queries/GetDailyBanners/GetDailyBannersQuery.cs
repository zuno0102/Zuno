using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.GetDailyBanners;

/// <summary>
/// The services on the customer home banner today.
/// </summary>
/// <remarks>
/// Seven at a time, and a different seven tomorrow. A home screen that shows the same businesses
/// every morning quietly becomes a ranking, and the businesses below the fold never get a turn —
/// so the window moves each day until every eligible service has had one.
/// </remarks>
public record GetDailyBannersQuery : IRequest<List<ServiceListingDto>>;
