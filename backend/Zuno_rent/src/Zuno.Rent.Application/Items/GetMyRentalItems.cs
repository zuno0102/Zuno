using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Application.Items;

/// <summary>The signed-in business's rent items, newest first, a page at a time.</summary>
public class GetMyRentalItemsQuery : IRequest<RentalItemPageDto>
{
    /// <summary>From 1.</summary>
    public int Page { get; set; } = 1;

    /// <summary>Null takes the configured default; anything above the configured maximum is capped.</summary>
    public int? PageSize { get; set; }

    /// <summary>True for only those available now, false for only those switched off, null for all.</summary>
    public bool? IsAvailable { get; set; }
}

public class GetMyRentalItemsQueryHandler(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IOptions<RentSettings> settings) : IRequestHandler<GetMyRentalItemsQuery, RentalItemPageDto>
{
    public async Task<RentalItemPageDto> Handle(GetMyRentalItemsQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var limits = settings.Value;
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize ?? limits.DefaultPageSize, 1, limits.MaxPageSize);

        var mine = dbContext.RentalItems.AsNoTracking().Where(i => i.OwnerUserId == ownerId);
        if (request.IsAvailable is { } available)
        {
            mine = mine.Where(i => i.IsAvailable == available);
        }

        var totalCount = await mine.CountAsync(cancellationToken);

        // Served by the (owner_user_id, created_date) index; the joins run as one query per list for
        // the whole page.
        var items = totalCount == 0
            ? new List<RentalItem>()
            : await mine
                .WithCard()
                .OrderByDescending(i => i.CreatedDate)
                .ThenBy(i => i.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

        return new RentalItemPageDto
        {
            Items = items.Select(i => i.ToDto()).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = totalCount,
        };
    }
}
