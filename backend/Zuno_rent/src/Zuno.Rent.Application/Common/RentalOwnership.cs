using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// Who is asking, and whether the item is theirs. The owner always comes from the signed-in user's
/// token, never from the request, and every change to an item checks it is that user's.
/// </summary>
internal static class RentalOwnership
{
    public static Guid OwnerId(this ICurrentUser currentUser) =>
        currentUser.UserId ?? throw new UnauthorizedAccessException("User is not authenticated.");

    /// <summary>Everything the item's card shows, tracked for changes — refused unless it is the caller's.</summary>
    public static async Task<RentalItem> OwnedItemAsync(
        this IRentDbContext dbContext, Guid rentalItemId, Guid ownerUserId, CancellationToken cancellationToken)
    {
        var item = await dbContext.RentalItems.WithCard()
            .FirstOrDefaultAsync(i => i.Id == rentalItemId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), rentalItemId);

        if (item.OwnerUserId != ownerUserId)
        {
            throw new ForbiddenException("This rent item does not belong to your business.");
        }

        return item;
    }

    /// <summary>The joins one item card needs. The context splits them into one query per list.</summary>
    public static IQueryable<RentalItem> WithCard(this IQueryable<RentalItem> items) =>
        items
            .Include(i => i.RentalCategory)
            .Include(i => i.RentalSubCategory)
            .Include(i => i.Media)
            .Include(i => i.Questions)
            .Include(i => i.Districts).ThenInclude(d => d.District).ThenInclude(d => d.State);
}
