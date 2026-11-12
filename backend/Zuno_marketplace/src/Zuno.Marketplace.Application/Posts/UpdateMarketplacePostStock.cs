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
        post.Quantity = request.Quantity;
        await dbContext.SaveChangesAsync(cancellationToken);
        return post.ToDto(clock.GetUtcNow(), await reference.TransitionsAsync(cancellationToken));
    }
}
