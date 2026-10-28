using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Customer.Queries.GetHomeSections;

/// <summary>
/// Builds the home screen's sections in one pass, so no service is in two of them.
/// </summary>
/// <remarks>
/// Composed here rather than in the app because only the server can see the whole catalogue at once.
/// Two rules shape every section:
///
///   * <b>one row per service name.</b> The catalogue holds many near-identical rows — a dozen
///     businesses all selling "Catering" — and a section that ranks them honestly shows the same word
///     a dozen times. Keeping the best of each name is what makes the page read as a catalogue rather
///     than a stutter.
///   * <b>nothing repeats between sections.</b> Each one takes what it needs and the next starts from
///     what is left, so scrolling always brings something new.
///
/// The order within the open sections is shuffled by a seed the client sends, so pulling to refresh
/// brings a different set of services while an ordinary rebuild — coming back from another tab — does
/// not move anything. With no seed it falls back to the date, which still changes daily.
/// </remarks>
public class GetHomeSectionsQueryHandler(
    IApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider,
    IPlatformSettings platformSettings,
    IReadCache readCache)
    : IRequestHandler<GetHomeSectionsQuery, HomeServiceSectionsDto>
{
    public async Task<HomeServiceSectionsDto> Handle(
        GetHomeSectionsQuery request,
        CancellationToken cancellationToken)
    {
        var rules = platformSettings.Current;

        // The catalogue and its booking counts are the same for every customer, so they are read once per
        // cache window, not once per request: on a million orders that read takes seconds. Only the
        // shuffle below is per request.
        var rows = rules.CustomerHomeCacheSeconds > 0
            ? await readCache.GetOrCreateAsync(
                "customer-home:candidates",
                TimeSpan.FromSeconds(rules.CustomerHomeCacheSeconds),
                LoadCandidatesAsync,
                cancellationToken)
            : await LoadCandidatesAsync(cancellationToken);

        var random = new Random(
            request.Seed ?? DateOnly.FromDateTime(dateTimeProvider.UtcNow.UtcDateTime).DayNumber);

        var shuffled = rows.OrderBy(_ => random.Next()).ToList();

        // Each section picks from the whole catalogue, skipping any name already used above it. One
        // shared set rather than trimming the pool first, because the right row for a name differs by
        // section: "Booked most often" wants the busiest business selling it, "Top rated" the
        // best-regarded. Deciding a single winner per name up front gave the top-rated strip one
        // entry, since the busiest sellers are mostly the ones nobody has reviewed.
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        List<ServiceListingDto> Pick(IEnumerable<Candidate> ordered, int count)
        {
            var picked = new List<ServiceListingDto>();

            foreach (var candidate in ordered)
            {
                if (picked.Count == count)
                {
                    break;
                }

                // Ten businesses selling "Catering" are ten real listings, but a page showing the
                // word ten times is not a catalogue.
                if (!used.Add(candidate.Listing.Name.Trim()))
                {
                    continue;
                }

                picked.Add(candidate.Listing);
            }

            return picked;
        }

        // Picks from the strongest few of a ranking, varied by the seed.
        //
        // A ranked section still has to change when somebody pulls to refresh, but shuffling a
        // ranking outright would make its heading a lie — the seventh most-booked service is not
        // "booked most often" if it only got there by coin toss. So the ranking decides a shortlist
        // several times the size of the section, and the seed decides which of that shortlist is
        // shown. Everything on screen is genuinely among the best by that measure; which of them you
        // see differs each time.
        List<ServiceListingDto> PickVaried(
            IEnumerable<Candidate> ordered,
            int count,
            int shortlistFactor = 3)
        {
            var namesInShortlist = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var shortlist = new List<Candidate>();

            foreach (var candidate in ordered)
            {
                if (shortlist.Count == count * shortlistFactor)
                {
                    break;
                }

                var name = candidate.Listing.Name.Trim();

                if (used.Contains(name) || !namesInShortlist.Add(name))
                {
                    continue;
                }

                shortlist.Add(candidate);
            }

            var picked = shortlist.OrderBy(_ => random.Next()).Take(count).ToList();

            foreach (var candidate in picked)
            {
                used.Add(candidate.Listing.Name.Trim());
            }

            return picked.Select(p => p.Listing).ToList();
        }

        // Top rated is chosen first, and the order of these two calls is the whole reason it has
        // anything in it. Only a handful of businesses have been reviewed at all, and the services
        // they sell are the same popular ones — so whichever section picks second finds its
        // candidates already taken. The scarcer section goes first.
        var topRated = PickVaried(
            shuffled
                .Where(r => r.Listing.ReviewCount >= rules.CustomerHomeMinReviewsForTopRated
                    && r.Listing.RatingAverage is not null)
                .OrderByDescending(r => r.Listing.RatingAverage)
                .ThenByDescending(r => r.Listing.ReviewCount),
            rules.CustomerHomeTopRatedCount);

        var mostBooked = PickVaried(
            shuffled.OrderByDescending(r => r.BookingCount)
                .ThenByDescending(r => r.Listing.RatingAverage ?? 0),
            rules.CustomerHomeMostBookedCount);

        var forYou = Pick(shuffled, rules.CustomerHomeForYouCount);
        var more = Pick(shuffled, rules.CustomerHomeMoreCount);

        // The long list at the bottom is the catalogue itself, so it repeats what the sections above
        // picked — somebody scrolling this far is looking for everything, not for what is left. Still
        // one row per name, for the same reason as above.
        var all = shuffled
            .GroupBy(r => r.Listing.Name.Trim(), StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First().Listing)
            .Take(rules.CustomerHomeAllCount)
            .ToList();

        return new HomeServiceSectionsDto
        {
            ForYou = forYou,
            MostBooked = mostBooked,
            More = more,
            TopRated = topRated,
            All = all,
        };
    }

    /// <summary>A service with the one fact the sections rank on that the DTO does not carry.</summary>
    /// <summary>Every bookable service with how often it has been booked — the pool each section picks from.</summary>
    private async Task<List<Candidate>> LoadCandidatesAsync(CancellationToken cancellationToken)
    {
        var services = await dbContext.BusinessServices
            .Where(s => s.IsActive)
            .Where(s => s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified)
            .Select(s => new ServiceListingDto
            {
                Id = s.Id,
                Name = s.Name,
                Description = s.Description,
                ServiceCategoryName = s.ServiceCategory.Name,
                ServiceCategoryId = s.ServiceCategoryId,
                Price = s.Price,
                PriceType = s.PriceType.ToString(),
                ImageUrl = s.Media
                        .OrderBy(m => m.SortOrder)
                        .Select(m => m.Url)
                        .FirstOrDefault(),
                BusinessOwnerProfileId = s.BusinessOwnerProfileId,
                BusinessName = s.BusinessOwnerProfile.BusinessName,
                BusinessLogoUrl = s.BusinessOwnerProfile.LogoUrl,
                City = s.BusinessOwnerProfile.BusinessAddress!.City,
                Level = s.BusinessOwnerProfile.Level,
                RatingAverage = s.BusinessOwnerProfile.CustomerRatingAverage,
                ReviewCount = s.BusinessOwnerProfile.CustomerReviewCount,
            })
        .ToListAsync(cancellationToken);

        // One grouped count over the orders, instead of a count per service inside the query above.
        var bookingCounts = await dbContext.Bookings
            .Where(b => b.BookingStatus != BookingStatus.Cancelled)
            .GroupBy(b => b.BusinessServiceId)
            .Select(g => new { ServiceId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.ServiceId, g => g.Count, cancellationToken);

        var levels = platformSettings.Current.BusinessLevels;
        foreach (var listing in services)
        {
            listing.LevelName = levels.Name(listing.Level);
        }

        return [.. services.Select(s => new Candidate(s, bookingCounts.GetValueOrDefault(s.Id)))];
    }


    private sealed record Candidate(ServiceListingDto Listing, int BookingCount);
}
