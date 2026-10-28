using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.GetHomeSections;

/// <summary>
/// Every section of the customer's home screen, composed so none of them repeat.
/// </summary>
/// <param name="Seed">
/// Which shuffle to use. The client sends a fresh one when somebody pulls to refresh, which is how
/// the page comes back with different services; it reuses the same one for ordinary rebuilds, so
/// returning from another tab does not reshuffle the page underneath them.
///
/// Null falls back to the date, so a client that never sends one still gets a page that changes daily
/// rather than the same order for ever.
/// </param>
/// <remarks>
/// Deliberately takes no location. The sections are the catalogue as a whole — what Zuno offers —
/// and a customer's chosen district narrows the band of results shown above them, not these. A
/// district with four businesses in it would otherwise turn the entire home screen into four cards.
/// </remarks>
public record GetHomeSectionsQuery(int? Seed = null) : IRequest<HomeServiceSectionsDto>;
