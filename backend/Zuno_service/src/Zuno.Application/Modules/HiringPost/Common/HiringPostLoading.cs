using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>How much of each application a hiring-post load brings with it.</summary>
public enum HiringPostCrewDetail
{
    /// <summary>
    /// Each application with its worker, the worker's account and payout details, and its wage
    /// changes — everything a post is shown, staffed and paid from.
    /// </summary>
    Full,

    /// <summary>
    /// The application rows alone, for rules that read only their statuses and wages (settlement,
    /// counts).
    /// </summary>
    /// <remarks>
    /// Not a cheaper <see cref="Full"/>: it also keeps an application whose worker has been
    /// soft-deleted, which a load that brings the worker drops (the worker is a required
    /// navigation, so its delete filter removes the row). A settlement or a hired count must still
    /// see that application.
    /// </remarks>
    ApplicationsOnly,
}

/// <summary>
/// Loads hiring posts with their applications in two steps: the posts first, then the applications
/// for exactly those posts in a query of their own. Attached to the posts by EF's relationship
/// fix-up, so the posts must be tracked — which every caller's are.
/// </summary>
/// <remarks>
/// <para>
/// Why not <c>Include(p =&gt; p.Applications).ThenInclude(...)</c>. With split queries, EF wrote the
/// applications query as the filtered posts joined to a subquery of <em>every</em> application with
/// its worker and user. Postgres hash-joined the whole applications table before the post filter
/// applied: 1–10 s a request on half a million applications, and the database fell over under load.
/// Filtered on the post ids directly it is an index lookup. The same fix as
/// <c>BookingRepository.LoadCrewAsync</c> for an order's crew.
/// </para>
/// <para>
/// The post's own reference navigations (business, sub-category, booking…) stay with the caller,
/// who includes them on the query it passes in. They differ per caller and some change the
/// response — a post loaded with its booking maps as linked to an order — so they are not unioned
/// here.
/// </para>
/// </remarks>
public static class HiringPostLoading
{
    /// <summary>The posts the query returns, in its order, each with its applications.</summary>
    public static async Task<List<Domain.Entities.HiringPost>> LoadHiringPostsAsync(
        this IApplicationDbContext dbContext,
        IQueryable<Domain.Entities.HiringPost> posts,
        CancellationToken cancellationToken,
        HiringPostCrewDetail detail = HiringPostCrewDetail.Full)
    {
        var loaded = await posts.ToListAsync(cancellationToken);
        if (loaded.Count > 0)
        {
            await dbContext.LoadHiringPostApplicationsAsync([.. loaded.Select(p => p.Id)], detail, cancellationToken);
        }

        return loaded;
    }

    /// <summary>The first post the query returns, with its applications; null when there is none.</summary>
    public static async Task<Domain.Entities.HiringPost?> LoadHiringPostAsync(
        this IApplicationDbContext dbContext,
        IQueryable<Domain.Entities.HiringPost> posts,
        CancellationToken cancellationToken,
        HiringPostCrewDetail detail = HiringPostCrewDetail.Full)
    {
        var post = await posts.FirstOrDefaultAsync(cancellationToken);
        if (post is not null)
        {
            await dbContext.LoadHiringPostApplicationsAsync([post.Id], detail, cancellationToken);
        }

        return post;
    }

    /// <summary>
    /// The first application the query returns, with its post and all of that post's applications —
    /// itself among them, as the same tracked instance. Null when there is none.
    /// </summary>
    /// <remarks>
    /// The query should include <c>a.HiringPost</c> plus whatever of the post the caller reads, and
    /// whatever of the application itself must exist for it to count (its worker, say): those are
    /// single-row joins. Only the post's applications are loaded here.
    /// </remarks>
    public static async Task<HiringPostApplication?> LoadHiringPostApplicationAsync(
        this IApplicationDbContext dbContext,
        IQueryable<HiringPostApplication> application,
        CancellationToken cancellationToken,
        HiringPostCrewDetail detail = HiringPostCrewDetail.Full)
    {
        var loaded = await application.FirstOrDefaultAsync(cancellationToken);
        if (loaded is not null)
        {
            await dbContext.LoadHiringPostApplicationsAsync([loaded.HiringPostId], detail, cancellationToken);
        }

        return loaded;
    }

    /// <summary>
    /// The applications of the given posts, attached to the tracked posts by relationship fix-up.
    /// </summary>
    /// <remarks>
    /// Loaded with <c>LoadAsync</c> rather than returned: nothing reads the list itself, only the
    /// posts' collections it fills. Row order is not kept — every reader orders the applications
    /// itself (by when they were made).
    /// </remarks>
    private static Task LoadHiringPostApplicationsAsync(
        this IApplicationDbContext dbContext,
        IReadOnlyCollection<Guid> postIds,
        HiringPostCrewDetail detail,
        CancellationToken cancellationToken)
    {
        var applications = dbContext.HiringPostApplications.Where(a => postIds.Contains(a.HiringPostId));

        if (detail == HiringPostCrewDetail.Full)
        {
            applications = applications
                .Include(a => a.WorkerProfile).ThenInclude(wp => wp.User)
                .Include(a => a.WorkerProfile).ThenInclude(wp => wp.PayoutDetail)
                .Include(a => a.SalaryAdjustments);
        }

        return applications.LoadAsync(cancellationToken);
    }
}
