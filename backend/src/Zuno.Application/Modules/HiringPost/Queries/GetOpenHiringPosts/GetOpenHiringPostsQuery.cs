using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Queries.GetOpenHiringPosts;

/// <summary>
/// The jobs a worker can see, optionally narrowed to ones near them.
/// </summary>
/// <remarks>
/// Every filter is optional, and with none of them supplied this behaves exactly as it always has:
/// every open future post, plus every post the worker has applied to. That is deliberate — the app
/// must keep working for a worker who has not given a location, or declined to.
/// </remarks>
public class GetOpenHiringPostsQuery : IRequest<List<HiringPostDto>>
{
    /// <summary>Where the worker is. Only has an effect together with <see cref="Longitude"/>.</summary>
    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>
    /// How far the worker is willing to travel. Ignored without a position to measure from.
    /// </summary>
    /// <remarks>
    /// A position with no radius still sorts the feed nearest-first and reports each distance; it just
    /// does not drop anything. That is the useful default for a worker who has shared where they are
    /// but not said how far they will go.
    /// </remarks>
    public double? RadiusKm { get; set; }

    /// <summary>Narrow to particular districts, independently of any radius.</summary>
    public List<Guid>? DistrictIds { get; set; }

    /// <summary>
    /// How many posts to return. Omitted, the platform's default page size; never more than its
    /// maximum, whatever is asked for — this query once returned every open post in the country.
    /// </summary>
    public int? Take { get; set; }
}
