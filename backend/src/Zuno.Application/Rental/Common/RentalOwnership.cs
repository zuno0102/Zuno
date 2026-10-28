using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;
using Zuno.Domain.Rental;

namespace Zuno.Application.Rental.Common;

/// <summary>
/// Who is asking, and whether the item is theirs. The business always comes from the signed-in
/// user's token, never from the request, and every change to an item checks it is that business's.
/// </summary>
internal static class RentalOwnership
{
    /// <summary>The signed-in user's business, or a refusal.</summary>
    public static async Task<Guid> BusinessIdAsync(
        ICurrentUserService currentUserService,
        IBusinessOwnerProfileRepository businessOwnerProfileRepository,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var business = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        return business.Id;
    }

    /// <summary>
    /// The item with everything its screen shows, tracked for changes — refused unless it belongs to
    /// <paramref name="businessId"/>.
    /// </summary>
    public static async Task<RentalItem> OwnedItemAsync(
        IRentalDbContext dbContext,
        Guid rentalItemId,
        Guid businessId,
        CancellationToken cancellationToken)
    {
        var item = await dbContext.RentalItems
            .Include(i => i.RentalCategory)
            .Include(i => i.RentalSubCategory)
            .Include(i => i.Media)
            .Include(i => i.Districts)
            .FirstOrDefaultAsync(i => i.Id == rentalItemId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), rentalItemId);

        if (item.BusinessOwnerProfileId != businessId)
        {
            throw new UnauthorizedAccessException("This rent item does not belong to your business.");
        }

        return item;
    }
}
