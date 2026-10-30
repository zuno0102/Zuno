using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Items;

/// <summary>The Stock page: each item with how many are in, out with customers, and in total.</summary>
public class GetMyRentalStockQuery : IRequest<RentalStockPageDto>
{
    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

/// <summary>One item's stock — chairs: 700 in, 300 out, 1000 in total.</summary>
public class RentalStockDto
{
    public Guid RentalItemId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string RentalCategoryName { get; set; } = string.Empty;

    public string? RentalSubCategoryName { get; set; }

    public bool IsAvailable { get; set; }

    /// <summary>What the business owns: in + out.</summary>
    public int QuantityTotal { get; set; }

    /// <summary>With customers now, on orders whose status counts as out.</summary>
    public int QuantityOut { get; set; }

    /// <summary>On hand: total − out.</summary>
    public int QuantityIn { get; set; }

    /// <summary>Promised to customers but not yet sent — still on hand, already spoken for.</summary>
    public int QuantityBooked { get; set; }

    /// <summary>The first photo, if any — the tile's picture.</summary>
    public string? ImageUrl { get; set; }
}

public class RentalStockPageDto
{
    public List<RentalStockDto> Items { get; set; } = [];

    public int Page { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }
}

public class GetMyRentalStockQueryHandler(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IOptions<RentSettings> settings) : IRequestHandler<GetMyRentalStockQuery, RentalStockPageDto>
{
    public async Task<RentalStockPageDto> Handle(GetMyRentalStockQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var limits = settings.Value;
        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize ?? limits.DefaultPageSize, 1, limits.MaxPageSize);

        var mine = dbContext.RentalItems.AsNoTracking().Where(i => i.OwnerUserId == ownerId);
        var totalCount = await mine.CountAsync(cancellationToken);
        var outOrders = dbContext.OutOrders();
        var bookedOrders = dbContext.BookedOrders();

        // One query for the page: the out count is a sum per item over the
        // (rental_item_id, status) index, not a row per order brought back.
        var rows = await mine
            .OrderBy(i => i.Name)
            .ThenBy(i => i.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new
            {
                i.Id,
                i.Name,
                Category = i.RentalCategory.Name,
                SubCategory = i.RentalSubCategory == null ? null : i.RentalSubCategory.Name,
                i.IsAvailable,
                i.QuantityOwned,
                Out = outOrders.Where(o => o.RentalItemId == i.Id).Sum(o => (int?)o.Quantity) ?? 0,
                Booked = bookedOrders.Where(o => o.RentalItemId == i.Id).Sum(o => (int?)o.Quantity) ?? 0,
                Image = i.Media
                    .Where(m => m.MediaType == RentalMediaType.Image)
                    .OrderBy(m => m.SortOrder)
                    .Select(m => m.Url)
                    .FirstOrDefault(),
            })
            .ToListAsync(cancellationToken);

        return new RentalStockPageDto
        {
            Items = rows.Select(r => new RentalStockDto
            {
                RentalItemId = r.Id,
                Name = r.Name,
                RentalCategoryName = r.Category,
                RentalSubCategoryName = r.SubCategory,
                IsAvailable = r.IsAvailable,
                QuantityTotal = r.QuantityOwned,
                QuantityOut = r.Out,
                QuantityIn = Math.Max(0, r.QuantityOwned - r.Out),
                QuantityBooked = r.Booked,
                ImageUrl = r.Image,
            }).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = totalCount,
        };
    }
}
