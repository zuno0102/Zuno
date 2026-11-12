using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;

namespace Zuno.Marketplace.Application.Common;

/// <summary>Turns a loaded post (with its card joins) into what the app shows.</summary>
internal static class MarketplacePostMapper
{
    public static MarketplacePostDto ToDto(
        this MarketplacePost post, DateTimeOffset now, IReadOnlyList<MarketplacePostTransition> transitions) =>
        new()
        {
            Id = post.Id,
            CategoryId = post.CategoryId,
            CategoryName = post.Category.Name,
            CategoryIconName = post.Category.IconName,
            SubCategoryId = post.SubCategoryId,
            SubCategoryName = post.SubCategory?.Name,
            Kind = post.Kind.ToString(),
            Status = post.ShownStatus(now).ToString(),
            Title = post.Title,
            Description = post.Description,
            Price = post.Price,
            PriceUnit = post.PriceUnit,
            TradeType = post.TradeType.ToString(),
            MinOrderQuantity = post.MinOrderQuantity,
            Quantity = post.Quantity,
            Condition = post.Condition?.ToString(),
            IsOutOfStock = post.IsOutOfStock,
            CanUpdateStock = post.KeepsStock && !post.IsFinal,
            OriginalPrice = post.OriginalPrice,
            StartsAt = post.StartsAt,
            EndsAt = post.EndsAt,
            ContactPhone = post.ContactPhone,
            DistrictId = post.DistrictId,
            DistrictName = post.District.Name,
            StateId = post.District.StateId,
            StateName = post.District.State.Name,
            Area = post.Area,
            Latitude = post.Latitude,
            Longitude = post.Longitude,
            Attributes = post.Attributes.ToDictionary(a => a.Key, a => a.Value),
            CustomDetails = post.CustomDetails.Select(d => new MarketplaceCustomDetailDto { Name = d.Key, Value = d.Value }).ToList(),
            Variants = post.Variants
                .OrderBy(v => v.SortOrder)
                .Select(v => new MarketplaceVariantDto { Id = v.Id, Colour = v.Colour, Size = v.Size, Name = v.Name, Price = v.Price, Stock = v.Stock })
                .ToList(),
            DeliversEverywhere = post.DeliversEverywhere,
            DeliveryStateId = post.DeliveryStateId,
            DeliveryDistrictIds = post.DeliveryDistrictIds,
            Media = post.Media
                .OrderBy(m => m.SortOrder)
                .Select(m => new MarketplacePostMediaDto { Url = m.Url, SortOrder = m.SortOrder })
                .ToList(),
            Actions = transitions
                .Where(t => t.AppliesTo(post))
                .Where(t => !(t.ToStatus == MarketplacePostStatus.Active && post.HasEnded(now)))
                .OrderBy(t => t.DisplayOrder)
                .Select(t => new MarketplacePostActionDto
                {
                    ToStatus = t.ToStatus.ToString(),
                    Name = t.ActionName,
                    NeedsConfirm = t.NeedsConfirm,
                })
                .ToList(),
            CreatedDate = post.CreatedDate,
        };
}
