using System.Globalization;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Settings;

/// <summary>
/// Every business rule the app owner can change, as typed values. Read from the
/// <c>platform_settings</c> table through <see cref="Interfaces.IPlatformSettings"/>.
/// </summary>
/// <remarks>
/// The initialisers are the built-in defaults and the values the table is seeded with, so a fresh
/// database behaves exactly as the code did before these became settings. Each rule declares the range
/// it may take: a row outside it, or one that does not parse, is ignored in favour of the default.
/// </remarks>
public sealed record PlatformRules
{
    // ---- Service area -------------------------------------------------------------------------

    /// <summary>Furthest a customer's pin may be from a served district's centre, in km.</summary>
    public double ServiceAreaMaxDistanceKm { get; init; } = 150;

    /// <summary>How far past the nearest district a pin may fall and still count as served, in km.</summary>
    public double ServiceAreaBorderSlackKm { get; init; } = 25;

    /// <summary>Furthest a pin may be from a district centre and still be said to be in it, in km.</summary>
    public double DistrictMatchMaxDistanceKm { get; init; } = 150;

    // ---- A worker's day -----------------------------------------------------------------------

    /// <summary>How long a job is assumed to run when its service gives no length, in minutes.</summary>
    public int DefaultJobMinutes { get; init; } = 120;

    /// <summary>The gap a worker needs between two jobs to get from one to the next, in minutes.</summary>
    public int TravelBufferMinutes { get; init; } = 30;

    // ---- Hiring posts -------------------------------------------------------------------------

    public int HiringPostMinDurationMinutes { get; init; } = 15;

    /// <summary>Longest job a post may describe. Also bounds the live-post query.</summary>
    public int HiringPostMaxDurationMinutes { get; init; } = 1440;

    /// <summary>Length a post gets when the business does not say.</summary>
    public int HiringPostDefaultDurationMinutes { get; init; } = 120;

    /// <summary>Most workers one hiring post may ask for.</summary>
    public int HiringPostMaxWorkers { get; init; } = 100;

    /// <summary>Most people one order's crew may be set to.</summary>
    public int OrderMaxCrewSize { get; init; } = 100;

    /// <summary>Most orders one list returns — a customer's, a business's or a worker's — newest first.</summary>
    public int OrderListMax { get; init; } = 500;

    public int HiringFeedDefaultPageSize { get; init; } = 60;

    public int HiringFeedMaxPageSize { get; init; } = 100;

    /// <summary>How many "applied, further away" and "no location" posts ride along with a nearby feed.</summary>
    public int HiringFeedSideGroupCap { get; init; } = 10;

    /// <summary>Rows a distance search reads before measuring true distance. A safety cap on one query.</summary>
    public int HiringFeedBoundingBoxRowCap { get; init; } = 500;

    // ---- Services -----------------------------------------------------------------------------

    /// <summary>Most questions a service may ask the customer.</summary>
    public int ServiceMaxQuestions { get; init; } = 15;

    /// <summary>Photo slots per service and per package.</summary>
    public int ServiceImageSlots { get; init; } = 3;

    /// <summary>Most services one customer search returns.</summary>
    public int ServiceSearchMaxPageSize { get; init; } = 100;

    /// <summary>Longest a service video may run, in seconds. Enforced by the app's recorder.</summary>
    public int ServiceVideoMaxSeconds { get; init; } = 30;

    // ---- Uploads and dates in the app --------------------------------------------------------

    /// <summary>JPEG quality, 1–100, the app compresses a photo to before uploading it.</summary>
    public int ImageUploadQuality { get; init; } = 85;

    /// <summary>Widest a photo is sent at, in pixels; larger ones are scaled down first.</summary>
    public int ImageUploadMaxWidth { get; init; } = 1600;

    /// <summary>Furthest ahead a date picker in the app reaches, in days.</summary>
    public int BookingMaxDaysAhead { get; init; } = 365;

    /// <summary>Furthest ahead a customer may book a service, in days.</summary>
    public int CustomerBookingMaxDaysAhead { get; init; } = 90;

    // ---- Full-time jobs -----------------------------------------------------------------------

    /// <summary>Most openings one full-time job post may offer.</summary>
    public int VacancyMaxOpenings { get; init; } = 999;

    /// <summary>Longest contract a full-time job post may describe, in months.</summary>
    public int VacancyMaxContractMonths { get; init; } = 60;

    // ---- Customer home ----------------------------------------------------------------------

    /// <summary>How long the home screen's catalogue is reused before it is read again, in seconds. 0 = every time.</summary>
    public int CustomerHomeCacheSeconds { get; init; } = 300;

    public int CustomerHomeForYouCount { get; init; } = 14;

    public int CustomerHomeMostBookedCount { get; init; } = 7;

    public int CustomerHomeMoreCount { get; init; } = 10;

    public int CustomerHomeTopRatedCount { get; init; } = 5;

    public int CustomerHomeAllCount { get; init; } = 40;

    /// <summary>Reviews a business needs before it can appear in "Top rated".</summary>
    public int CustomerHomeMinReviewsForTopRated { get; init; } = 1;

    // ---- Dashboards ---------------------------------------------------------------------------

    public int BusinessDashboardTrendMonths { get; init; } = 6;

    public int BusinessDashboardDetailLimit { get; init; } = 50;

    public int WorkerDashboardTrendMonths { get; init; } = 6;

    public int WorkerDashboardDetailLimit { get; init; } = 25;

    // ---- Levels -------------------------------------------------------------------------------

    /// <summary>The business ladder. Rungs from <c>level_definitions</c>; review minimum from this table.</summary>
    public LevelLadder BusinessLevels { get; init; } = LevelLadder.BusinessDefaults;

    /// <summary>The worker ladder. Rungs from <c>level_definitions</c>; minimums from this table.</summary>
    public LevelLadder WorkerLevels { get; init; } = LevelLadder.WorkerDefaults;

    /// <summary>The defaults, as the code ships them.</summary>
    public static PlatformRules Defaults { get; } = new();

    /// <summary>A requested page size for a customer service search, held inside the configured bounds.</summary>
    public int ServiceSearchPageSize(int requested) =>
        Math.Clamp(requested, 1, ServiceSearchMaxPageSize);

    /// <summary>A requested page size for the worker hiring feed, held inside the configured bounds.</summary>
    public int HiringFeedPageSize(int? requested) =>
        requested is > 0 ? Math.Min(requested.Value, HiringFeedMaxPageSize) : HiringFeedDefaultPageSize;

    /// <summary>
    /// Every rule: its key, what it does, the range it may take, and how to read and apply it. The one
    /// list the seed data, the parser and the admin screen all work from, so they cannot disagree.
    /// </summary>
    public static IReadOnlyList<PlatformRuleDefinition> Definitions { get; } =
    [
        Number("service-area.max-distance-km", "Furthest a customer may be from a served district's centre (km).", 1, 1000,
            r => r.ServiceAreaMaxDistanceKm, (r, v) => r with { ServiceAreaMaxDistanceKm = v }),
        Number("service-area.border-slack-km", "How far past the nearest district a customer may be and still be served (km).", 0, 500,
            r => r.ServiceAreaBorderSlackKm, (r, v) => r with { ServiceAreaBorderSlackKm = v }),
        Number("district.match-max-distance-km", "Furthest a pin may be from a district centre and still be placed in it (km).", 1, 1000,
            r => r.DistrictMatchMaxDistanceKm, (r, v) => r with { DistrictMatchMaxDistanceKm = v }),
        Whole("schedule.default-job-minutes", "Job length assumed when a service gives none (minutes).", 15, 1440,
            r => r.DefaultJobMinutes, (r, v) => r with { DefaultJobMinutes = v }),
        Whole("schedule.travel-buffer-minutes", "Gap a worker needs between two jobs (minutes).", 0, 240,
            r => r.TravelBufferMinutes, (r, v) => r with { TravelBufferMinutes = v }),
        Whole("hiring-post.min-duration-minutes", "Shortest job a hiring post may describe (minutes).", 5, 1440,
            r => r.HiringPostMinDurationMinutes, (r, v) => r with { HiringPostMinDurationMinutes = v }),
        Whole("hiring-post.max-duration-minutes", "Longest job a hiring post may describe (minutes).", 15,
            Domain.Entities.HiringPost.LongestSupportedDurationMinutes,
            r => r.HiringPostMaxDurationMinutes, (r, v) => r with { HiringPostMaxDurationMinutes = v }),
        Whole("hiring-post.default-duration-minutes", "Length a hiring post gets when none is given (minutes).", 15, 1440,
            r => r.HiringPostDefaultDurationMinutes, (r, v) => r with { HiringPostDefaultDurationMinutes = v }),
        Whole("hiring-post.max-workers", "Most workers one hiring post may ask for.", 1, 10000,
            r => r.HiringPostMaxWorkers, (r, v) => r with { HiringPostMaxWorkers = v }),
        Whole("order.list-max", "Most orders one list shows, newest first (performance cap).", 20, 5000,
            r => r.OrderListMax, (r, v) => r with { OrderListMax = v }),
        Whole("order.max-crew-size", "Most people one order's crew may be set to.", 1, 10000,
            r => r.OrderMaxCrewSize, (r, v) => r with { OrderMaxCrewSize = v }),
        Whole("hiring-feed.default-page-size", "Jobs shown per page in a worker's Find work feed.", 1, 500,
            r => r.HiringFeedDefaultPageSize, (r, v) => r with { HiringFeedDefaultPageSize = v }),
        Whole("hiring-feed.max-page-size", "Most jobs a worker's Find work feed may ask for at once.", 1, 500,
            r => r.HiringFeedMaxPageSize, (r, v) => r with { HiringFeedMaxPageSize = v }),
        Whole("hiring-feed.side-group-cap", "Further-away and unlocated jobs added to a nearby feed.", 0, 100,
            r => r.HiringFeedSideGroupCap, (r, v) => r with { HiringFeedSideGroupCap = v }),
        Whole("hiring-feed.bounding-box-row-cap", "Rows a distance search reads before measuring (performance cap).", 50, 5000,
            r => r.HiringFeedBoundingBoxRowCap, (r, v) => r with { HiringFeedBoundingBoxRowCap = v }),
        Whole("service.max-questions", "Most questions a service may ask the customer.", 0, 50,
            r => r.ServiceMaxQuestions, (r, v) => r with { ServiceMaxQuestions = v }),
        Whole("service-search.max-page-size", "Most services one customer search returns (performance cap).", 10, 500,
            r => r.ServiceSearchMaxPageSize, (r, v) => r with { ServiceSearchMaxPageSize = v }),
        Whole("service.image-slots", "Photo slots per service and per package.", 1, 10,
            r => r.ServiceImageSlots, (r, v) => r with { ServiceImageSlots = v }),
        Whole("service.video-max-seconds", "Longest a service video may run (seconds).", 5, 300,
            r => r.ServiceVideoMaxSeconds, (r, v) => r with { ServiceVideoMaxSeconds = v }),
        Whole("media.image-quality", "JPEG quality the app compresses photos to before upload (1-100).", 30, 100,
            r => r.ImageUploadQuality, (r, v) => r with { ImageUploadQuality = v }),
        Whole("media.image-max-width", "Widest a photo is uploaded at (pixels).", 320, 4096,
            r => r.ImageUploadMaxWidth, (r, v) => r with { ImageUploadMaxWidth = v }),
        Whole("schedule.max-days-ahead", "Furthest ahead a date can be picked in the app (days).", 7, 730,
            r => r.BookingMaxDaysAhead, (r, v) => r with { BookingMaxDaysAhead = v }),
        Whole("booking.customer-max-days-ahead", "Furthest ahead a customer may book a service (days).", 1, 730,
            r => r.CustomerBookingMaxDaysAhead, (r, v) => r with { CustomerBookingMaxDaysAhead = v }),
        Whole("vacancy.max-openings", "Most openings one full-time job post may offer.", 1, 9999,
            r => r.VacancyMaxOpenings, (r, v) => r with { VacancyMaxOpenings = v }),
        Whole("vacancy.max-contract-months", "Longest contract a full-time job post may describe (months).", 1, 120,
            r => r.VacancyMaxContractMonths, (r, v) => r with { VacancyMaxContractMonths = v }),
        Whole("customer-home.cache-seconds", "How long the customer home catalogue is reused before re-reading it (seconds; 0 = never).", 0, 3600,
            r => r.CustomerHomeCacheSeconds, (r, v) => r with { CustomerHomeCacheSeconds = v }),
        Whole("customer-home.for-you-count", "Services in the customer home 'For you' grid.", 0, 100,
            r => r.CustomerHomeForYouCount, (r, v) => r with { CustomerHomeForYouCount = v }),
        Whole("customer-home.most-booked-count", "Services in the customer home 'Booked most often' strip.", 0, 50,
            r => r.CustomerHomeMostBookedCount, (r, v) => r with { CustomerHomeMostBookedCount = v }),
        Whole("customer-home.more-count", "Services in the customer home 'More to explore' strip.", 0, 50,
            r => r.CustomerHomeMoreCount, (r, v) => r with { CustomerHomeMoreCount = v }),
        Whole("customer-home.top-rated-count", "Services in the customer home 'Top rated' strip.", 0, 50,
            r => r.CustomerHomeTopRatedCount, (r, v) => r with { CustomerHomeTopRatedCount = v }),
        Whole("customer-home.all-count", "Services in the customer home full list.", 0, 500,
            r => r.CustomerHomeAllCount, (r, v) => r with { CustomerHomeAllCount = v }),
        Whole("customer-home.top-rated-min-reviews", "Reviews a business needs to appear in 'Top rated'.", 1, 100,
            r => r.CustomerHomeMinReviewsForTopRated, (r, v) => r with { CustomerHomeMinReviewsForTopRated = v }),
        Whole("business-dashboard.trend-months", "Months shown on the business home trend chart.", 1, 24,
            r => r.BusinessDashboardTrendMonths, (r, v) => r with { BusinessDashboardTrendMonths = v }),
        Whole("business-dashboard.detail-limit", "Rows in each business home list.", 5, 500,
            r => r.BusinessDashboardDetailLimit, (r, v) => r with { BusinessDashboardDetailLimit = v }),
        Whole("worker-dashboard.trend-months", "Months shown on the worker home trend chart.", 1, 24,
            r => r.WorkerDashboardTrendMonths, (r, v) => r with { WorkerDashboardTrendMonths = v }),
        Whole("worker-dashboard.detail-limit", "Rows in each worker home list.", 5, 500,
            r => r.WorkerDashboardDetailLimit, (r, v) => r with { WorkerDashboardDetailLimit = v }),
        Whole("business-level.min-reviews-for-average", "Reviews a business needs before its average counts towards its level.", 1, 100,
            r => r.BusinessLevels.MinimumReviewsForAverage,
            (r, v) => r with { BusinessLevels = r.BusinessLevels with { MinimumReviewsForAverage = v } }),
        Whole("worker-level.min-reviews-for-average", "Ratings a worker needs before their average counts towards their level.", 1, 100,
            r => r.WorkerLevels.MinimumReviewsForAverage,
            (r, v) => r with { WorkerLevels = r.WorkerLevels with { MinimumReviewsForAverage = v } }),
        Whole("worker-level.min-offers-for-rate", "Offers a worker needs before their answered-offers rate counts towards their level.", 1, 100,
            r => r.WorkerLevels.MinimumOffersForRate,
            (r, v) => r with { WorkerLevels = r.WorkerLevels with { MinimumOffersForRate = v } }),
    ];

    /// <summary>
    /// Builds the rules from stored key/value rows. Unknown keys are ignored; a value that does not
    /// parse or falls outside its range keeps the default and is reported through <paramref name="rejected"/>.
    /// </summary>
    public static PlatformRules From(
        IReadOnlyDictionary<string, string> values,
        Action<string, string>? rejected = null)
    {
        var rules = Defaults;

        foreach (var definition in Definitions)
        {
            if (!values.TryGetValue(definition.Key, out var raw))
            {
                continue;
            }

            if (definition.TryApply(rules, raw, out var updated))
            {
                rules = updated;
            }
            else
            {
                rejected?.Invoke(definition.Key, raw);
            }
        }

        // Rules that only make sense together. A pair stored out of order keeps both defaults rather
        // than leaving, say, a minimum above the maximum.
        if (rules.HiringPostMinDurationMinutes > rules.HiringPostMaxDurationMinutes
            || rules.HiringPostDefaultDurationMinutes < rules.HiringPostMinDurationMinutes
            || rules.HiringPostDefaultDurationMinutes > rules.HiringPostMaxDurationMinutes)
        {
            rejected?.Invoke("hiring-post.*-duration-minutes", "minimum, default and maximum out of order");
            rules = rules with
            {
                HiringPostMinDurationMinutes = Defaults.HiringPostMinDurationMinutes,
                HiringPostMaxDurationMinutes = Defaults.HiringPostMaxDurationMinutes,
                HiringPostDefaultDurationMinutes = Defaults.HiringPostDefaultDurationMinutes,
            };
        }

        if (rules.HiringFeedDefaultPageSize > rules.HiringFeedMaxPageSize)
        {
            rejected?.Invoke("hiring-feed.*-page-size", "default above maximum");
            rules = rules with
            {
                HiringFeedDefaultPageSize = Defaults.HiringFeedDefaultPageSize,
                HiringFeedMaxPageSize = Defaults.HiringFeedMaxPageSize,
            };
        }

        return rules;
    }

    /// <summary>
    /// These rules with one ladder's rungs replaced by rows from <c>level_definitions</c>. No rows keeps the
    /// built-in rungs; rows that do not make a usable ladder keep them too, and are reported.
    /// </summary>
    public PlatformRules WithLevelRungs(
        LevelAudience audience,
        IReadOnlyList<LevelRung> rungs,
        Action<string, string>? rejected = null)
    {
        if (rungs.Count == 0)
        {
            return this;
        }

        if (LevelLadder.Problem(rungs) is { } problem)
        {
            rejected?.Invoke($"level-definitions:{audience}", problem);
            return this;
        }

        IReadOnlyList<LevelRung> ordered = [.. rungs.OrderBy(r => r.Level)];

        return audience == LevelAudience.Business
            ? this with { BusinessLevels = BusinessLevels with { Rungs = ordered } }
            : this with { WorkerLevels = WorkerLevels with { Rungs = ordered } };
    }

    private static PlatformRuleDefinition Whole(
        string key, string description, int min, int max,
        Func<PlatformRules, int> read, Func<PlatformRules, int, PlatformRules> write) =>
        new(key, description, min, max,
            r => read(r).ToString(CultureInfo.InvariantCulture),
            (r, raw) => int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) && v >= min && v <= max
                ? write(r, v)
                : null);

    private static PlatformRuleDefinition Number(
        string key, string description, double min, double max,
        Func<PlatformRules, double> read, Func<PlatformRules, double, PlatformRules> write) =>
        new(key, description, min, max,
            r => read(r).ToString(CultureInfo.InvariantCulture),
            (r, raw) => double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var v)
                        && v >= min && v <= max && double.IsFinite(v)
                ? write(r, v)
                : null);
}
