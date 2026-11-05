using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Ratings;

/// <summary>
/// The customer rates a rental that went well — returned and fully paid — once. The stars go to the
/// item and to the business that rented it out.
/// </summary>
public class RateRentalOrderCommand : IRequest<RentalOrderDto>
{
    /// <summary>The order, from the route.</summary>
    public Guid Id { get; set; }

    public short Score { get; set; }

    public string? Comment { get; set; }
}

public class RateRentalOrderCommandValidator : AbstractValidator<RateRentalOrderCommand>
{
    public RateRentalOrderCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Score)
            .InclusiveBetween(RentalRatingFields.MinScore, RentalRatingFields.MaxScore)
            .WithMessage($"Choose from {RentalRatingFields.MinScore} to {RentalRatingFields.MaxScore} stars.");
        RuleFor(x => x.Comment).MaximumLength(RentalRatingFields.CommentMaxLength);
    }
}

/// <summary>
/// Every business's Rent rating totals and successful rentals, for the Service API to fold into the
/// one business rating customers see. Plain totals, not averages, so the two can be added together.
/// </summary>
public class GetRentalReputationQuery : IRequest<RentalReputationDto>;

public class RentalReputationDto
{
    public List<RentalBusinessReputationDto> Items { get; set; } = [];
}

/// <summary>One business's totals. The field names are a contract with the Service API — do not rename them.</summary>
public class RentalBusinessReputationDto
{
    public Guid OwnerUserId { get; set; }

    /// <summary>All its rating scores added up.</summary>
    public decimal RatingSum { get; set; }

    public int RatingCount { get; set; }

    /// <summary>Main orders returned and fully paid.</summary>
    public int SuccessfulOrders { get; set; }
}

/// <summary>An item's stars: the fair average (null under the minimum count) and how many rated it.</summary>
public readonly record struct RentalItemRating(decimal? Average, int Count)
{
    public static readonly RentalItemRating None = new(null, 0);
}

/// <summary>Reads items' stars for a whole page at once — one grouped query, never one per item.</summary>
internal static class RentalItemRatings
{
    public static async Task<Dictionary<Guid, RentalItemRating>> RatingsForAsync(
        this IRentDbContext dbContext, IReadOnlyCollection<Guid> itemIds, CancellationToken cancellationToken)
    {
        if (itemIds.Count == 0)
        {
            return [];
        }

        // Served by the rental_item_id index.
        var totals = await dbContext.RentalOrderRatings
            .AsNoTracking()
            .Where(r => itemIds.Contains(r.RentalItemId))
            .GroupBy(r => r.RentalItemId)
            .Select(g => new { ItemId = g.Key, Sum = g.Sum(r => (int)r.Score), Count = g.Count() })
            .ToListAsync(cancellationToken);

        return totals.ToDictionary(t => t.ItemId, t => new RentalItemRating(FairRating.Of(t.Sum, t.Count), t.Count));
    }

    public static RentalItemRating For(this Dictionary<Guid, RentalItemRating> ratings, Guid itemId) =>
        ratings.GetValueOrDefault(itemId, RentalItemRating.None);
}

public class RentalRatingHandlers(ICurrentUser currentUser, IRentDbContext dbContext) :
    IRequestHandler<RateRentalOrderCommand, RentalOrderDto>,
    IRequestHandler<GetRentalReputationQuery, RentalReputationDto>
{
    public async Task<RentalOrderDto> Handle(RateRentalOrderCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(request.Id, customerId, RentalAudience.Customer, cancellationToken);

        var order = await dbContext.RentalOrders
            .AsNoTracking()
            .Where(o => o.Id == request.Id)
            .Select(o => new { o.Id, o.RentalItemId, o.OwnerUserId, o.ParentOrderId, o.Status, o.Amount })
            .SingleAsync(cancellationToken);

        if (order.ParentOrderId is not null)
        {
            throw new DomainException("Extra pieces are rated with the rental they were added to.");
        }

        var paid = await dbContext.NetPaidAsync(order.Id, cancellationToken);
        if (!RentalOrderSuccess.IsSuccessful(order.Status, order.ParentOrderId, order.Amount, paid))
        {
            throw new DomainException("You can rate a rental once it is returned and fully paid.");
        }

        // The unique index on the order is the final word if two taps race past this check.
        if (await dbContext.RentalOrderRatings.AnyAsync(r => r.RentalOrderId == order.Id, cancellationToken))
        {
            throw new DomainException("You have already rated this rental.");
        }

        dbContext.RentalOrderRatings.Add(new RentalOrderRating
        {
            RentalOrderId = order.Id,
            RentalItemId = order.RentalItemId,
            OwnerUserId = order.OwnerUserId,
            CustomerUserId = customerId,
            Score = request.Score,
            Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim(),
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, order.Id, customerId, cancellationToken, RentalAudience.Customer);
    }

    public async Task<RentalReputationDto> Handle(GetRentalReputationQuery request, CancellationToken cancellationToken)
    {
        // Two grouped reads — one row per business each — joined here.
        var ratings = await dbContext.RentalOrderRatings
            .AsNoTracking()
            .GroupBy(r => r.OwnerUserId)
            .Select(g => new { OwnerUserId = g.Key, Sum = g.Sum(r => (int)r.Score), Count = g.Count() })
            .ToDictionaryAsync(g => g.OwnerUserId, cancellationToken);

        var successful = await dbContext.SuccessfulOrders()
            .AsNoTracking()
            .GroupBy(o => o.OwnerUserId)
            .Select(g => new { OwnerUserId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.OwnerUserId, g => g.Count, cancellationToken);

        return new RentalReputationDto
        {
            Items = ratings.Keys
                .Union(successful.Keys)
                .Order()
                .Select(owner =>
                {
                    var rated = ratings.GetValueOrDefault(owner);
                    return new RentalBusinessReputationDto
                    {
                        OwnerUserId = owner,
                        RatingSum = rated?.Sum ?? 0,
                        RatingCount = rated?.Count ?? 0,
                        SuccessfulOrders = successful.GetValueOrDefault(owner),
                    };
                })
                .ToList(),
        };
    }
}
