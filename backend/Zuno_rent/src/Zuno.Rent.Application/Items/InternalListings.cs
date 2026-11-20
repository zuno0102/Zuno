using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Items;

/// <summary>A live rent item, as the Service API counts it for the business's plan.</summary>
public record LiveListingDto(Guid Id, DateTimeOffset CreatedDate);

/// <summary>The business's rent items that are switched on, oldest first (for the Service API only).</summary>
public record GetLiveListingsQuery(Guid OwnerUserId) : IRequest<List<LiveListingDto>>;

/// <summary>
/// Switches the business's own items in <see cref="Ids"/> off (a plan ended) or back on (renewed).
/// Ids that are not this business's are ignored. For the Service API only.
/// </summary>
public record SetListingsLiveCommand(Guid OwnerUserId, List<Guid> Ids, bool Live) : IRequest<Unit>;

public static class RentalPlanRoom
{
    /// <summary>Asks the plan before one more item goes live; <paramref name="exceptItemId"/> is the item being switched on.</summary>
    public static async Task EnsurePlanRoomAsync(
        this IRentDbContext dbContext, IServicePlanGate planGate, Guid ownerUserId, Guid? exceptItemId, CancellationToken cancellationToken)
    {
        var live = await dbContext.RentalItems.CountAsync(
            i => i.OwnerUserId == ownerUserId && i.IsAvailable && i.Id != exceptItemId, cancellationToken);
        await planGate.EnsureCanAddAsync(live, cancellationToken);
    }
}

public class InternalListingHandlers(IRentDbContext dbContext) :
    IRequestHandler<GetLiveListingsQuery, List<LiveListingDto>>,
    IRequestHandler<SetListingsLiveCommand, Unit>
{
    public Task<List<LiveListingDto>> Handle(GetLiveListingsQuery request, CancellationToken cancellationToken) =>
        dbContext.RentalItems.AsNoTracking()
            .Where(i => i.OwnerUserId == request.OwnerUserId && i.IsAvailable)
            .OrderBy(i => i.CreatedDate)
            .Select(i => new LiveListingDto(i.Id, i.CreatedDate))
            .ToListAsync(cancellationToken);

    public async Task<Unit> Handle(SetListingsLiveCommand request, CancellationToken cancellationToken)
    {
        var items = await dbContext.RentalItems
            .Where(i => i.OwnerUserId == request.OwnerUserId && request.Ids.Contains(i.Id))
            .ToListAsync(cancellationToken);
        foreach (var item in items)
        {
            item.IsAvailable = request.Live;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}
