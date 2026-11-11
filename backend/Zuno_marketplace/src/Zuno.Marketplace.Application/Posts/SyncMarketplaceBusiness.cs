using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>
/// Copies the business's Service profile into Marketplace — name, logo, verified — which decides
/// whether customers see its posts. The app calls it when the Marketplace tab opens.
/// </summary>
public class SyncMarketplaceBusinessCommand : IRequest<MarketplaceBusinessDto>;

public class MarketplaceBusinessDto
{
    public string Name { get; set; } = string.Empty;

    public string? LogoUrl { get; set; }

    public bool IsVerified { get; set; }

    /// <summary>False when Service could not be asked and nothing was known before.</summary>
    public bool IsKnown { get; set; }
}

public class SyncMarketplaceBusinessCommandHandler(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IServiceDirectory directory,
    TimeProvider clock) : IRequestHandler<SyncMarketplaceBusinessCommand, MarketplaceBusinessDto>
{
    public async Task<MarketplaceBusinessDto> Handle(SyncMarketplaceBusinessCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var profile = await directory.GetCurrentBusinessAsync(cancellationToken);
        var row = await dbContext.Businesses.FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken);

        // Service unreachable: what was known is kept rather than hiding the business's posts.
        if (profile is not null)
        {
            if (row is null)
            {
                row = new MarketplaceBusiness { OwnerUserId = ownerId };
                dbContext.Businesses.Add(row);
            }

            row.Name = profile.Name;
            row.LogoUrl = profile.LogoUrl;
            row.IsVerified = profile.IsVerified;
            row.RefreshedAt = clock.GetUtcNow();
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return row is null
            ? new MarketplaceBusinessDto()
            : new MarketplaceBusinessDto { Name = row.Name, LogoUrl = row.LogoUrl, IsVerified = row.IsVerified, IsKnown = true };
    }
}
