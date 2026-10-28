using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;
using Zuno.Domain.Rental;

namespace Zuno.Application.Rental.Common;

/// <summary>
/// Turns rent items into what the app shows. District names live in the shared districts table,
/// which the Rent module only reads: they are fetched in one query for the whole batch, never one
/// per item.
/// </summary>
internal static class RentalItemMapper
{
    public static async Task<List<RentalItemDto>> ToDtosAsync(
        IReadOnlyCollection<RentalItem> items,
        IApplicationDbContext coreDbContext,
        CancellationToken cancellationToken)
    {
        var districtIds = items.SelectMany(i => i.Districts).Select(d => d.DistrictId).Distinct().ToList();

        var districts = districtIds.Count == 0
            ? new Dictionary<Guid, RentalItemDistrictDto>()
            : await coreDbContext.Districts
                .AsNoTracking()
                .Where(d => districtIds.Contains(d.Id))
                .Select(d => new RentalItemDistrictDto
                {
                    Id = d.Id,
                    Name = d.Name,
                    StateId = d.StateId,
                    StateName = d.State.Name,
                })
                .ToDictionaryAsync(d => d.Id, cancellationToken);

        return items.Select(i => ToDto(i, districts)).ToList();
    }

    public static async Task<RentalItemDto> ToDtoAsync(
        RentalItem item,
        IApplicationDbContext coreDbContext,
        CancellationToken cancellationToken) =>
        (await ToDtosAsync([item], coreDbContext, cancellationToken))[0];

    private static RentalItemDto ToDto(RentalItem item, IReadOnlyDictionary<Guid, RentalItemDistrictDto> districts) => new()
    {
        Id = item.Id,
        RentalCategoryId = item.RentalCategoryId,
        RentalCategoryName = item.RentalCategory?.Name ?? string.Empty,
        RentalSubCategoryId = item.RentalSubCategoryId,
        RentalSubCategoryName = item.RentalSubCategory?.Name,
        Name = item.Name,
        Description = item.Description,
        PriceType = item.PriceType.ToString(),
        Price = item.Price,
        QuantityOwned = item.QuantityOwned,
        IsAvailable = item.IsAvailable,
        Media = item.Media
            .Where(m => !m.IsDeleted)
            .OrderBy(m => m.MediaType == ServiceMediaType.Video)
            .ThenBy(m => m.SortOrder)
            .Select(m => new RentalItemMediaDto
            {
                Id = m.Id,
                MediaType = m.MediaType.ToString(),
                Url = m.Url,
                SortOrder = m.SortOrder,
            })
            .ToList(),

        // A district removed from the shared table since is simply left out, not shown blank.
        Districts = item.Districts
            .Where(d => !d.IsDeleted)
            .Select(d => districts.GetValueOrDefault(d.DistrictId))
            .OfType<RentalItemDistrictDto>()
            .OrderBy(d => d.Name)
            .ToList(),
    };
}
