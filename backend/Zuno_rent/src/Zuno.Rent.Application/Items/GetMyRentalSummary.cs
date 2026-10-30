using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Items;

/// <summary>The business home screen's Rent tiles: how many items, how many can be rented now, and how many pieces.</summary>
public class GetMyRentalSummaryQuery : IRequest<RentalSummaryDto>;

public class RentalSummaryDto
{
    public int TotalItems { get; set; }

    public int AvailableItems { get; set; }

    public int UnavailableItems { get; set; }

    /// <summary>Pieces across the items available now — 200 chairs and 1 cutting machine make 201.</summary>
    public long UnitsAvailable { get; set; }
}

public class GetMyRentalSummaryQueryHandler(ICurrentUser currentUser, IRentDbContext dbContext)
    : IRequestHandler<GetMyRentalSummaryQuery, RentalSummaryDto>
{
    public async Task<RentalSummaryDto> Handle(GetMyRentalSummaryQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();

        // One aggregate over the owner's rows (owner index), not a list counted in the app: the
        // tiles stay right however many items a business lists.
        var totals = await dbContext.RentalItems
            .AsNoTracking()
            .Where(i => i.OwnerUserId == ownerId)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Total = g.Count(),
                Available = g.Count(i => i.IsAvailable),
                Units = g.Where(i => i.IsAvailable).Sum(i => (long)i.QuantityOwned),
            })
            .FirstOrDefaultAsync(cancellationToken);

        return new RentalSummaryDto
        {
            TotalItems = totals?.Total ?? 0,
            AvailableItems = totals?.Available ?? 0,
            UnavailableItems = (totals?.Total ?? 0) - (totals?.Available ?? 0),
            UnitsAvailable = totals?.Units ?? 0,
        };
    }
}
