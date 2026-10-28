using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyJobOffers;

/// <summary>
/// Jobs a business has invited this worker onto and that are still waiting on their answer.
/// </summary>
/// <remarks>
/// Its own query rather than a filter over the Find work feed, and the reason is that the feed is a
/// search: narrowed by distance, ordered by it, and cut to a page. An offer is not something a
/// worker went looking for — a business picked them for it by name — so it must never be the row
/// that fell off the end of a page or sat outside a radius somebody set last week.
/// </remarks>
public record GetMyJobOffersQuery : IRequest<List<HiringPostDto>>;
