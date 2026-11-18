using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Orders;

/// <summary>A buyer asks a seller for a B2B lot.</summary>
public class CreateMarketplaceB2BRequestCommand : IRequest<MarketplaceB2BRequestDto>
{
    public Guid PostId { get; set; }

    public int Quantity { get; set; }

    public string? Message { get; set; }
}

/// <summary>The seller's requests, narrowed to a status, with a count per status.</summary>
public class GetBusinessB2BRequestsQuery : IRequest<MarketplaceB2BRequestPageDto>
{
    /// <summary>E.g. <c>Requested</c>; null for every request.</summary>
    public string? Status { get; set; }

    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

/// <summary>The seller accepts or declines. Accepting shares the two sides' contacts.</summary>
public class RespondMarketplaceB2BRequestCommand : IRequest<MarketplaceB2BRequestDto>
{
    public Guid Id { get; set; }

    public bool Accept { get; set; }
}

/// <summary>The buyer's own requests; a seller's contact only with a B2B plan running.</summary>
public class GetMyB2BRequestsQuery : IRequest<MarketplaceB2BRequestPageDto>
{
    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

public class CreateMarketplaceB2BRequestCommandValidator : AbstractValidator<CreateMarketplaceB2BRequestCommand>
{
    public CreateMarketplaceB2BRequestCommandValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.PostId).NotEmpty();
        RuleFor(x => x.Quantity).InclusiveBetween(1, settings.Value.MaxQuantity);
        RuleFor(x => x.Message).MaximumLength(MarketplaceOrderLimits.MessageLength);
    }
}

public class GetBusinessB2BRequestsQueryValidator : AbstractValidator<GetBusinessB2BRequestsQuery>
{
    public GetBusinessB2BRequestsQueryValidator() =>
        RuleFor(x => x.Status)
            .Must(s => Enum.TryParse<MarketplaceB2BRequestStatus>(s, true, out var v) && Enum.IsDefined(v))
            .When(x => !string.IsNullOrWhiteSpace(x.Status))
            .WithMessage("Unknown request status.");
}

public class MarketplaceB2BRequestHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IServiceDirectory directory,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<CreateMarketplaceB2BRequestCommand, MarketplaceB2BRequestDto>,
    IRequestHandler<GetBusinessB2BRequestsQuery, MarketplaceB2BRequestPageDto>,
    IRequestHandler<RespondMarketplaceB2BRequestCommand, MarketplaceB2BRequestDto>,
    IRequestHandler<GetMyB2BRequestsQuery, MarketplaceB2BRequestPageDto>
{
    public async Task<MarketplaceB2BRequestDto> Handle(CreateMarketplaceB2BRequestCommand request, CancellationToken cancellationToken)
    {
        var buyerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var post = await dbContext.Posts.AsNoTracking()
            .VisibleToCustomers(dbContext.Businesses, now)
            .FirstOrDefaultAsync(p => p.Id == request.PostId && p.TradeType == MarketplaceTradeType.Wholesale, cancellationToken)
            ?? throw new DomainException("This B2B lot is not on offer just now.");

        if (post.OwnerUserId == buyerId)
        {
            throw new DomainException("You cannot ask for your own lot.");
        }

        var unit = string.IsNullOrWhiteSpace(post.PriceUnit) ? string.Empty : $" {post.PriceUnit}";
        if (post.MinOrderQuantity is { } least && request.Quantity < least)
        {
            throw new DomainException($"The smallest order is {least}{unit}. Ask for at least that.");
        }

        if (post.Quantity is { } available && request.Quantity > available)
        {
            throw new DomainException($"Only {available}{unit} available. Ask for that or less.");
        }

        var open = await dbContext.B2BRequests.AnyAsync(
            r => r.PostId == post.Id && r.BuyerUserId == buyerId && r.Status == MarketplaceB2BRequestStatus.Requested, cancellationToken);
        if (open)
        {
            throw new DomainException("You have already asked for this lot. Wait for the seller's answer.");
        }

        var person = await directory.GetCurrentPersonAsync(cancellationToken);
        var row = new MarketplaceB2BRequest
        {
            PostId = post.Id,
            OwnerUserId = post.OwnerUserId,
            BuyerUserId = buyerId,
            BuyerName = person?.Name ?? "Buyer",
            BuyerPhone = person?.Phone,
            Title = post.Title,
            Quantity = request.Quantity,
            Unit = post.PriceUnit,
            UnitPrice = post.Price,
            Message = string.IsNullOrWhiteSpace(request.Message) ? null : request.Message.Trim(),
        };
        dbContext.B2BRequests.Add(row);
        await dbContext.SaveChangesAsync(cancellationToken);

        var statuses = await reference.B2BRequestStatusesAsync(cancellationToken);
        return ToDto(row, post.MinOrderQuantity, statuses, asSeller: false, buyerHasPlan: false);
    }

    public async Task<MarketplaceB2BRequestPageDto> Handle(GetBusinessB2BRequestsQuery request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);
        var statuses = await reference.B2BRequestStatusesAsync(cancellationToken);
        var mine = dbContext.B2BRequests.AsNoTracking().Where(r => r.OwnerUserId == ownerId);

        var counts = await mine.GroupBy(r => r.Status)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, cancellationToken);
        var filtered = Enum.TryParse<MarketplaceB2BRequestStatus>(request.Status, true, out var status) ? mine.Where(r => r.Status == status) : mine;
        var total = await filtered.CountAsync(cancellationToken);
        var rows = await filtered
            .OrderByDescending(r => r.CreatedDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var minimums = await MinimumsAsync(rows, cancellationToken);

        return new MarketplaceB2BRequestPageDto
        {
            Items = rows.Select(r => ToDto(r, minimums.GetValueOrDefault(r.PostId), statuses, asSeller: true, buyerHasPlan: false)).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
            Counts = MarketplaceOrderCore.Counts(statuses.Select(s => s.Code), counts),
        };
    }

    public async Task<MarketplaceB2BRequestDto> Handle(RespondMarketplaceB2BRequestCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var row = await dbContext.B2BRequests.FirstOrDefaultAsync(r => r.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException("Request", request.Id);
        if (row.OwnerUserId != ownerId)
        {
            throw new ForbiddenException("This request is not for your business.");
        }

        var target = request.Accept ? MarketplaceB2BRequestStatus.Accepted : MarketplaceB2BRequestStatus.Declined;
        if (row.Status != target)
        {
            if (row.Status != MarketplaceB2BRequestStatus.Requested)
            {
                throw new DomainException("This request has already been answered.");
            }

            if (request.Accept)
            {
                // The seller's contact as their accounts have it now, for the buyer to call.
                var business = await directory.GetCurrentBusinessAsync(cancellationToken);
                var person = await directory.GetCurrentPersonAsync(cancellationToken);
                row.SellerName = business?.Name
                    ?? await dbContext.Businesses.Where(b => b.OwnerUserId == ownerId).Select(b => b.Name).FirstOrDefaultAsync(cancellationToken);
                row.SellerPhone = person?.Phone;
                if (row.SellerPhone is null)
                {
                    throw new DomainException("Your mobile number could not be read just now, so the buyer could not reach you. Try again in a moment.");
                }
            }

            row.Status = target;
            row.RespondedAt = clock.GetUtcNow();
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var statuses = await reference.B2BRequestStatusesAsync(cancellationToken);
        var minimums = await MinimumsAsync([row], cancellationToken);
        return ToDto(row, minimums.GetValueOrDefault(row.PostId), statuses, asSeller: true, buyerHasPlan: false);
    }

    public async Task<MarketplaceB2BRequestPageDto> Handle(GetMyB2BRequestsQuery request, CancellationToken cancellationToken)
    {
        var buyerId = currentUser.OwnerId();
        var (page, pageSize) = MarketplaceQueries.Paging(request.Page, request.PageSize, settings.Value);
        var statuses = await reference.B2BRequestStatusesAsync(cancellationToken);
        var hasPlan = await dbContext.HasB2BBuyerPlanAsync(buyerId, clock.GetUtcNow(), cancellationToken);
        var mine = dbContext.B2BRequests.AsNoTracking().Where(r => r.BuyerUserId == buyerId);
        var total = await mine.CountAsync(cancellationToken);
        var rows = await mine.OrderByDescending(r => r.CreatedDate).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(cancellationToken);
        var minimums = await MinimumsAsync(rows, cancellationToken);

        return new MarketplaceB2BRequestPageDto
        {
            Items = rows.Select(r => ToDto(r, minimums.GetValueOrDefault(r.PostId), statuses, asSeller: false, buyerHasPlan: hasPlan)).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
        };
    }

    /// <summary>
    /// The request as <paramref name="asSeller"/> or the buyer may see it: the seller sees the buyer's
    /// phone once they accept; the buyer sees the seller's only when accepted and their B2B plan runs.
    /// </summary>
    private static MarketplaceB2BRequestDto ToDto(
        MarketplaceB2BRequest row,
        int? minOrderQuantity,
        IReadOnlyList<MarketplaceB2BRequestStatusOption> statuses,
        bool asSeller,
        bool buyerHasPlan)
    {
        var status = statuses.FirstOrDefault(s => s.Code == row.Status);
        var accepted = row.Status == MarketplaceB2BRequestStatus.Accepted;
        return new MarketplaceB2BRequestDto
        {
            Id = row.Id,
            Number = MarketplaceOrderCore.Number(row.Id),
            PostId = row.PostId,
            Title = row.Title,
            Quantity = row.Quantity,
            Unit = row.Unit,
            UnitPrice = row.UnitPrice,
            Total = row.UnitPrice * row.Quantity,
            MinOrderQuantity = minOrderQuantity,
            Message = row.Message,
            Status = row.Status.ToString(),
            StatusName = status?.Name ?? row.Status.ToString(),
            StatusTone = status?.Tone ?? "waiting",
            BuyerName = row.BuyerName,
            BuyerPhone = asSeller && accepted ? row.BuyerPhone : null,
            SellerName = accepted ? row.SellerName : null,
            SellerPhone = !asSeller && accepted && buyerHasPlan ? row.SellerPhone : null,
            ContactNeedsPlan = !asSeller && accepted && !buyerHasPlan,
            CreatedDate = row.CreatedDate,
            RespondedAt = row.RespondedAt,
        };
    }

    /// <summary>Each lot's smallest order, read now: shown beside the quantity asked.</summary>
    private Task<Dictionary<Guid, int?>> MinimumsAsync(IReadOnlyCollection<MarketplaceB2BRequest> rows, CancellationToken cancellationToken)
    {
        var postIds = rows.Select(r => r.PostId).Distinct().ToList();
        return dbContext.Posts.AsNoTracking().IgnoreQueryFilters()
            .Where(p => postIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, p => p.MinOrderQuantity, cancellationToken);
    }
}
