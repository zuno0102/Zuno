using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Queries.GetHiringBusiness;

/// <summary>A hiring business as a worker sees it: what it pays, and whether it pays.</summary>
/// <param name="Latitude">
/// Where the worker is, so each open job can say how far away it is. Optional, and both halves are
/// needed or neither counts.
///
/// Measured here rather than in the app so this screen and the Find work feed answer "how far" the
/// same way. Two implementations of the same formula is two chances for a job to read as 12 km on
/// one screen and 14 km on the next.
/// </param>
public record GetHiringBusinessQuery(
    Guid BusinessOwnerProfileId,
    double? Latitude = null,
    double? Longitude = null) : IRequest<HiringBusinessDto>;
