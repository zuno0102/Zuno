using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Customer.DTOs;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Customer.Queries.GetDailyBanners;

/// <summary>
/// Picks today's banner services, and a different set tomorrow.
/// </summary>
/// <remarks>
/// The rotation is arithmetic rather than random: the window starts at
/// <c>(day number × 7) mod total</c> over a stable ordering, so every device asking on the same day
/// gets the same seven, tomorrow's seven are the next seven along, and nothing repeats until every
/// eligible service has had its turn. Random picking would show some businesses twice in a week and
/// others never, which is the thing a rotating banner exists to avoid.
///
/// Eligibility is deliberately narrow: active, from a verified business, and carrying a picture. A
/// banner is mostly photograph, and a service with none would be a grey rectangle with a name on it.
///
/// When promoted listings arrive this is the one place that changes — a <c>Where</c> on the paid flag
/// and a different ordering. Everything downstream, on the server and in the app, stays as it is.
/// </remarks>
public class GetDailyBannersQueryHandler(
    IApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider)
    : IRequestHandler<GetDailyBannersQuery, List<ServiceListingDto>>
{
    /// <summary>How many a customer sees at once, and how far the window moves overnight.</summary>
    public const int BannerCount = 7;

    public async Task<List<ServiceListingDto>> Handle(
        GetDailyBannersQuery request,
        CancellationToken cancellationToken)
    {
        var eligible = dbContext.BusinessServices
            .Where(s => s.IsActive)
            .Where(s => s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified)
            // A banner is a picture. Without one there is nothing to put on it.
            .Where(s => s.Media.Any());

        // Ordered by id, which is arbitrary but fixed — the window has to land on the same services
        // all day, and any ordering that changes as businesses are rated or edited would reshuffle
        // the banner under somebody mid-scroll.
        var candidates = await eligible
            .OrderBy(s => s.Id)
            .Select(s => new { s.Id, s.BusinessOwnerProfileId })
            .ToListAsync(cancellationToken);

        // One service per business. A business that has listed forty of them would otherwise fill
        // the banner on its own — which is what happens here today — and a strip showing the same
        // name seven times showcases nothing. Their other services are still a tap away.
        var ids = candidates
            .GroupBy(c => c.BusinessOwnerProfileId)
            .Select(g => g.First().Id)
            .ToList();

        if (ids.Count == 0)
        {
            return [];
        }

        var todaysIds = Window(ids, dateTimeProvider.UtcNow, BannerCount);

        var listings = await dbContext.BusinessServices
            .Where(s => todaysIds.Contains(s.Id))
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

        foreach (var listing in listings)
        {
            listing.LevelName = BusinessLevel.Name(listing.Level);
        }

        // Back into the order the window chose. `Contains` returns rows in whatever order the
        // database likes, and the banner should open on the same one all day.
        return todaysIds
            .Select(id => listings.FirstOrDefault(l => l.Id == id))
            .OfType<ServiceListingDto>()
            .ToList();
    }

    /// <summary>
    /// The slice of <paramref name="ids"/> that belongs to this day, wrapping round the end.
    /// </summary>
    /// <remarks>
    /// Internal and pure so the rotation can be tested without a database: the properties worth
    /// proving are that consecutive days do not overlap, that the sequence comes back round, and that
    /// a catalogue smaller than one page still fills the banner.
    /// </remarks>
    public static List<Guid> Window(List<Guid> ids, DateTimeOffset now, int count)
    {
        if (ids.Count == 0 || count <= 0)
        {
            return [];
        }

        // Fewer services than a page: everybody is on it, every day. Rotating here would only hide
        // somebody for no reason.
        if (ids.Count <= count)
        {
            return [.. ids];
        }

        // Days since the epoch, so the window advances at midnight UTC rather than on a timer tied
        // to when the server last restarted.
        var day = DateOnly.FromDateTime(now.UtcDateTime).DayNumber;
        var start = (int)(((long)day * count) % ids.Count);

        return [.. Enumerable.Range(0, count).Select(i => ids[(start + i) % ids.Count])];
    }
}
