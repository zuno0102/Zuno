using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>A live post, as the Service API counts it for the business's plan.</summary>
public record LiveListingDto(Guid Id, DateTimeOffset CreatedDate);

/// <summary>The business's live posts, oldest first (for the Service API only).</summary>
public record GetLiveListingsQuery(Guid OwnerUserId) : IRequest<List<LiveListingDto>>;

/// <summary>
/// Pauses the business's own live posts in <see cref="Ids"/> (a plan ended), or puts paused ones back
/// up (renewed). Other posts and ids that are not this business's are left alone. For the Service API only.
/// </summary>
public record SetListingsLiveCommand(Guid OwnerUserId, List<Guid> Ids, bool Live) : IRequest<Unit>;

public class InternalListingHandlers(IMarketplaceDbContext dbContext, TimeProvider clock) :
    IRequestHandler<GetLiveListingsQuery, List<LiveListingDto>>,
    IRequestHandler<SetListingsLiveCommand, Unit>
{
    public Task<List<LiveListingDto>> Handle(GetLiveListingsQuery request, CancellationToken cancellationToken) =>
        dbContext.Posts.AsNoTracking()
            .Where(p => p.OwnerUserId == request.OwnerUserId)
            .Live(clock.GetUtcNow())
            .OrderBy(p => p.CreatedDate)
            .Select(p => new LiveListingDto(p.Id, p.CreatedDate))
            .ToListAsync(cancellationToken);

    public async Task<Unit> Handle(SetListingsLiveCommand request, CancellationToken cancellationToken)
    {
        var from = request.Live ? MarketplacePostStatus.Paused : MarketplacePostStatus.Active;
        var posts = await dbContext.Posts
            .Where(p => p.OwnerUserId == request.OwnerUserId && request.Ids.Contains(p.Id) && p.Status == from)
            .ToListAsync(cancellationToken);
        foreach (var post in posts)
        {
            post.Status = request.Live ? MarketplacePostStatus.Active : MarketplacePostStatus.Paused;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}
