using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>
/// Sets how many of a new item are left — the quick "Update stock" on the post's menu, without the
/// whole form. 0 is out of stock: the post stays listed but customers do not see it until restocked.
/// </summary>
public class UpdateMarketplacePostStockCommand : IRequest<MarketplacePostDto>
{
    public Guid Id { get; set; }

    /// <summary>Which colour / size, on a product that has them; null for the post's one count.</summary>
    public Guid? VariantId { get; set; }

    public int Quantity { get; set; }
}

public class UpdateMarketplacePostStockCommandValidator : AbstractValidator<UpdateMarketplacePostStockCommand>
{
    public UpdateMarketplacePostStockCommandValidator(IOptions<MarketplaceSettings> settings)
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Quantity).InclusiveBetween(0, settings.Value.MaxQuantity);
    }
}

public class UpdateMarketplacePostStockHandler(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    TimeProvider clock) : IRequestHandler<UpdateMarketplacePostStockCommand, MarketplacePostDto>
{
    public async Task<MarketplacePostDto> Handle(UpdateMarketplacePostStockCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(request.Id, currentUser.OwnerId(), cancellationToken);
        if (!post.KeepsStock)
        {
            throw new DomainException("Only a new item keeps a stock count.");
        }

        if (post.IsFinal)
        {
            throw new DomainException("A closed or sold post cannot be changed.");
        }

        // A stock change never takes or frees a plan slot: an out-of-stock post is still listed.
        if (post.Variants.Count == 0)
        {
            if (request.VariantId is not null)
            {
                throw new DomainException("This product has no colours or sizes.");
            }

            post.Quantity = request.Quantity;
        }
        else
        {
            var variant = post.Variants.FirstOrDefault(v => v.Id == request.VariantId)
                ?? throw new DomainException("Choose which colour or size to update.");
            variant.Stock = request.Quantity;
            post.Quantity = post.Variants.Sum(v => v.Stock);
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        return post.ToDto(clock.GetUtcNow(), await reference.TransitionsAsync(cancellationToken));
    }
}
