using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Application.Common;

/// <summary>
/// Copies the business's Service profile into Rent: name, logo, verified — and the UPI ID its order
/// QR is made from. The profile is the one place a business sets these, so Rent never asks for them
/// twice.
/// </summary>
public static class RentalBusinessRefresh
{
    /// <summary>
    /// Asks Service for the signed-in business and keeps the answer. Returns the row, or null when
    /// Service could not be asked and nothing was known before — what was known is kept rather than
    /// hiding the business's items.
    /// </summary>
    public static async Task<RentalBusiness?> RefreshAsync(
        IRentDbContext dbContext,
        IServiceDirectory directory,
        Guid ownerId,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var profile = await directory.GetCurrentBusinessAsync(cancellationToken);
        var row = await dbContext.RentalBusinesses.FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken);
        if (profile is null)
        {
            return row;
        }

        if (row is null)
        {
            row = new RentalBusiness { OwnerUserId = ownerId };
            dbContext.RentalBusinesses.Add(row);
        }

        row.Name = profile.Name;
        row.LogoUrl = profile.LogoUrl;
        row.IsVerified = profile.IsVerified;
        row.RefreshedAt = now;

        // A profile without one keeps the ID saved in Rent before the profile held it, so an
        // existing QR keeps working until the business finishes its profile.
        if (!string.IsNullOrWhiteSpace(profile.UpiId))
        {
            row.UpiId = profile.UpiId.Trim().ToLowerInvariant();
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return row;
    }
}
