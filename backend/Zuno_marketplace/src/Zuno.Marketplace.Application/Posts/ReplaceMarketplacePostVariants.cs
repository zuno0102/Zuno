using FluentValidation;
using MediatR;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>
/// "Manage variants": sets a new product's colours and sizes, each with its price and stock, without
/// the whole form. The rest of the post is kept as saved and the edit's own rules run on the result,
/// so a colour / size is checked exactly as the form would check it.
/// </summary>
public class ReplaceMarketplacePostVariantsCommand : IRequest<MarketplacePostDto>
{
    public Guid Id { get; set; }

    /// <summary>Every colour / size the product is sold in, in order; one sent with an id keeps that row.</summary>
    public List<MarketplaceVariantInput> Variants { get; set; } = [];
}

public class ReplaceMarketplacePostVariantsCommandValidator : AbstractValidator<ReplaceMarketplacePostVariantsCommand>
{
    public ReplaceMarketplacePostVariantsCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        // None at all is one stock count again: that is the form's Edit, where the stock is typed.
        RuleFor(x => x.Variants).NotEmpty().WithMessage("Keep at least one colour or size.");
        RuleFor(x => x.Variants.Count).LessThanOrEqualTo(MarketplacePostFieldsValidator<UpdateMarketplacePostCommand>.MaxVariants)
            .OverridePropertyName("Variants")
            .WithMessage($"Add at most {MarketplacePostFieldsValidator<UpdateMarketplacePostCommand>.MaxVariants} colours and sizes.");
    }
}

public class ReplaceMarketplacePostVariantsHandler(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    IValidator<UpdateMarketplacePostCommand> editValidator,
    IRequestHandler<UpdateMarketplacePostCommand, MarketplacePostDto> edit) : IRequestHandler<ReplaceMarketplacePostVariantsCommand, MarketplacePostDto>
{
    public async Task<MarketplacePostDto> Handle(ReplaceMarketplacePostVariantsCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(request.Id, currentUser.OwnerId(), cancellationToken);
        if (!post.KeepsStock)
        {
            throw new DomainException("Only a new product is sold in colours and sizes.");
        }

        var changed = AsEdit(post);
        changed.Variants = request.Variants;
        await editValidator.ValidateAndThrowAsync(changed, cancellationToken);
        return await edit.Handle(changed, cancellationToken);
    }

    /// <summary>The post as saved, as the form would send it back unchanged.</summary>
    public static UpdateMarketplacePostCommand AsEdit(MarketplacePost post) => new()
    {
        Id = post.Id,
        CategoryId = post.CategoryId,
        SubCategoryId = post.SubCategoryId,
        Title = post.Title,
        Description = post.Description,
        Price = post.Price,
        PriceUnit = post.PriceUnit,
        TradeType = post.TradeType.ToString(),
        MinOrderQuantity = post.MinOrderQuantity,
        Quantity = post.Quantity,
        PackQuantity = post.PackQuantity,
        Condition = post.Condition?.ToString(),
        OriginalPrice = post.OriginalPrice,
        StartsAt = post.StartsAt,
        EndsAt = post.EndsAt,
        ContactPhone = post.ContactPhone,
        DistrictId = post.DistrictId,
        Area = post.Area,
        Latitude = post.Latitude,
        Longitude = post.Longitude,
        Attributes = post.Attributes.ToDictionary(a => a.Key, a => (string?)a.Value),
        CustomDetails = [.. post.CustomDetails.Select(d => new MarketplaceCustomDetailInput { Name = d.Key, Value = d.Value })],
        Variants = [.. post.Variants.OrderBy(v => v.SortOrder).Select(v => new MarketplaceVariantInput
        {
            Id = v.Id,
            Colour = v.Colour,
            Size = v.Size,
            Price = v.Price,
            Stock = v.Stock,
            IsActive = v.IsActive,
            CustomDetails = [.. v.CustomDetails.Select(d => new MarketplaceCustomDetailInput { Name = d.Key, Value = d.Value })],
        })],
        DeliversEverywhere = post.DeliversEverywhere,
        DeliveryStateId = post.DeliveryStateId,
        DeliveryDistrictIds = [.. post.DeliveryDistrictIds],
    };
}
