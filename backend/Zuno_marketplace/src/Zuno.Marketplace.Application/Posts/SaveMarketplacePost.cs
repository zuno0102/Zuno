using System.Globalization;
using FluentValidation;
using FluentValidation.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Posts;

/// <summary>What the post form sends, for a new post and an edit alike.</summary>
public abstract class MarketplacePostFields
{
    public Guid CategoryId { get; set; }

    /// <summary>Required while the category has sub-categories, e.g. Sarees under Products.</summary>
    public Guid? SubCategoryId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public decimal? Price { get; set; }

    public string? PriceUnit { get; set; }

    /// <summary><c>Retail</c> or <c>Wholesale</c>; empty means Retail.</summary>
    public string? TradeType { get; set; }

    public int? MinOrderQuantity { get; set; }

    /// <summary>How many are for sale; for a new item in a category that keeps stock, the stock (0 = out of stock).</summary>
    public int? Quantity { get; set; }

    /// <summary>Products only: how many in one item sold (a pack of 3 is 3). Left out, it is 1.</summary>
    public int? PackQuantity { get; set; }

    /// <summary><c>New</c> or <c>Used</c>: required in a category that keeps stock (Products), ignored elsewhere.</summary>
    public string? Condition { get; set; }

    public decimal? OriginalPrice { get; set; }

    public DateTimeOffset? StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    public string? ContactPhone { get; set; }

    public Guid DistrictId { get; set; }

    public string? Area { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    /// <summary>The category's own details, by field key. Keys the category does not have are refused.</summary>
    public Dictionary<string, string?> Attributes { get; set; } = [];

    /// <summary>Details the business names itself, in its order — "Leather type: Genuine".</summary>
    public List<MarketplaceCustomDetailInput> CustomDetails { get; set; } = [];

    /// <summary>A new product's colours and sizes, each with its stock. Empty for one stock count.</summary>
    public List<MarketplaceVariantInput> Variants { get; set; } = [];

    /// <summary>Products only: ships all over India (the default), or only in <see cref="DeliveryStateId"/>.</summary>
    public bool DeliversEverywhere { get; set; } = true;

    /// <summary>The state it ships in, when not everywhere. Required then; an older app leaves it out.</summary>
    public Guid? DeliveryStateId { get; set; }

    /// <summary>Districts of that state it ships to; empty ships to the whole state.</summary>
    public List<Guid> DeliveryDistrictIds { get; set; } = [];
}

/// <summary>One detail the business adds itself.</summary>
public class MarketplaceCustomDetailInput
{
    public string Name { get; set; } = string.Empty;

    public string Value { get; set; } = string.Empty;
}

/// <summary>One colour / size of a new product. <see cref="Id"/> keeps an existing one on an edit.</summary>
public class MarketplaceVariantInput
{
    public Guid? Id { get; set; }

    public string? Colour { get; set; }

    public string? Size { get; set; }

    /// <summary>Null sells at the post's price.</summary>
    public decimal? Price { get; set; }

    public int Stock { get; set; }
}

/// <summary>Puts up a new post. It goes live at once, so it needs a free slot on the business's plan.</summary>
public class CreateMarketplacePostCommand : MarketplacePostFields, IRequest<MarketplacePostDto>;

/// <summary>Changes a post. The route decides which; an id in the body is ignored.</summary>
public class UpdateMarketplacePostCommand : MarketplacePostFields, IRequest<MarketplacePostDto>
{
    public Guid Id { get; set; }
}

/// <summary>The checks that need nothing but the request. The category's own rules run in the handler.</summary>
public abstract class MarketplacePostFieldsValidator<T> : AbstractValidator<T>
    where T : MarketplacePostFields
{
    public const int MaxAttributes = 30;
    public const int MaxCustomDetails = 15;
    public const int MaxVariants = 50;
    public const int MaxDeliveryDistricts = 100;

    protected MarketplacePostFieldsValidator(IOptions<MarketplaceSettings> settings)
    {
        var limits = settings.Value;
        RuleFor(x => x.CategoryId).NotEmpty();
        RuleFor(x => x.DistrictId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(MarketplaceTextLimits.Title);
        RuleFor(x => x.Description).MaximumLength(MarketplaceTextLimits.Description);
        RuleFor(x => x.PriceUnit).MaximumLength(MarketplaceTextLimits.PriceUnit);
        RuleFor(x => x.Area).MaximumLength(MarketplaceTextLimits.Area);
        RuleFor(x => x.Price).GreaterThan(0).LessThanOrEqualTo(limits.MaxPrice).When(x => x.Price.HasValue);
        RuleFor(x => x.OriginalPrice).GreaterThan(0).LessThanOrEqualTo(limits.MaxPrice).When(x => x.OriginalPrice.HasValue);
        RuleFor(x => x.Quantity).InclusiveBetween(0, limits.MaxQuantity).When(x => x.Quantity.HasValue);
        RuleFor(x => x.PackQuantity).InclusiveBetween(1, limits.MaxQuantity).When(x => x.PackQuantity.HasValue);
        RuleFor(x => x.MinOrderQuantity).InclusiveBetween(1, limits.MaxQuantity).When(x => x.MinOrderQuantity.HasValue);
        RuleFor(x => x.TradeType)
            .Must(t => string.IsNullOrEmpty(t) || Enum.TryParse<MarketplaceTradeType>(t, ignoreCase: true, out var parsed) && Enum.IsDefined(parsed))
            .WithMessage("Trade type must be Retail or Wholesale.");
        RuleFor(x => x.Condition)
            .Must(c => string.IsNullOrEmpty(c) || Enum.TryParse<MarketplaceItemCondition>(c, ignoreCase: true, out var parsed) && Enum.IsDefined(parsed))
            .WithMessage("Condition must be New or Used.");
        RuleFor(x => x.ContactPhone).Matches(MarketplaceTextLimits.ContactPhonePattern).When(x => !string.IsNullOrEmpty(x.ContactPhone))
            .WithMessage($"Contact phone must be {MarketplaceTextLimits.ContactPhoneMinDigits} to {MarketplaceTextLimits.ContactPhoneMaxDigits} digits.");
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90).When(x => x.Latitude.HasValue);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180).When(x => x.Longitude.HasValue);
        RuleFor(x => x).Must(x => x.Latitude.HasValue == x.Longitude.HasValue)
            .WithName("Location").WithMessage("Send both latitude and longitude, or neither.");
        RuleFor(x => x.CustomDetails.Count).LessThanOrEqualTo(MaxCustomDetails)
            .OverridePropertyName("CustomDetails").WithMessage($"Add at most {MaxCustomDetails} details of your own.");
        RuleForEach(x => x.CustomDetails).ChildRules(detail =>
        {
            detail.RuleFor(d => d.Name).NotEmpty().WithMessage("Name the detail, e.g. Leather type.").MaximumLength(MarketplaceTextLimits.CustomDetailName);
            detail.RuleFor(d => d.Value).NotEmpty().WithMessage("Give the detail a value.").MaximumLength(MarketplaceTextLimits.AttributeValue);
        });
        RuleFor(x => x.Variants.Count).LessThanOrEqualTo(MaxVariants)
            .OverridePropertyName("Variants").WithMessage($"Add at most {MaxVariants} colours and sizes.");
        RuleForEach(x => x.Variants).ChildRules(variant =>
        {
            variant.RuleFor(v => v).Must(v => !string.IsNullOrWhiteSpace(v.Colour) || !string.IsNullOrWhiteSpace(v.Size))
                .OverridePropertyName("Colour").WithMessage("Give a colour, a size, or both.");
            variant.RuleFor(v => v.Colour).MaximumLength(MarketplaceTextLimits.Colour);
            variant.RuleFor(v => v.Size).MaximumLength(MarketplaceTextLimits.Size);
            variant.RuleFor(v => v.Stock).InclusiveBetween(0, limits.MaxQuantity);
            variant.RuleFor(v => v.Price).GreaterThan(0).LessThanOrEqualTo(limits.MaxPrice).When(v => v.Price.HasValue);
        });
        RuleFor(x => x.DeliveryDistrictIds.Count).LessThanOrEqualTo(MaxDeliveryDistricts)
            .OverridePropertyName("DeliveryDistrictIds").WithMessage($"Choose at most {MaxDeliveryDistricts} districts.");
        RuleFor(x => x.Attributes.Count).LessThanOrEqualTo(MaxAttributes).OverridePropertyName("Attributes");
        RuleForEach(x => x.Attributes).Must(a => (a.Value?.Length ?? 0) <= MarketplaceTextLimits.AttributeValue)
            .WithMessage($"Each detail must be {MarketplaceTextLimits.AttributeValue} characters or fewer.");
    }
}

public class CreateMarketplacePostCommandValidator(IOptions<MarketplaceSettings> settings)
    : MarketplacePostFieldsValidator<CreateMarketplacePostCommand>(settings);

public class UpdateMarketplacePostCommandValidator : MarketplacePostFieldsValidator<UpdateMarketplacePostCommand>
{
    public UpdateMarketplacePostCommandValidator(IOptions<MarketplaceSettings> settings)
        : base(settings) => RuleFor(x => x.Id).NotEmpty();
}

/// <summary>Creates and edits posts, checking the category's rules, the district, ownership and the plan's limit.</summary>
public class SaveMarketplacePostHandlers(
    ICurrentUser currentUser,
    IMarketplaceDbContext dbContext,
    MarketplaceReference reference,
    TimeProvider clock,
    IOptions<MarketplaceSettings> settings) :
    IRequestHandler<CreateMarketplacePostCommand, MarketplacePostDto>,
    IRequestHandler<UpdateMarketplacePostCommand, MarketplacePostDto>
{
    public async Task<MarketplacePostDto> Handle(CreateMarketplacePostCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var category = await CheckedCategoryAsync(request, now, cancellationToken);

        var post = new MarketplacePost { OwnerUserId = ownerId, Status = MarketplacePostStatus.Active };
        Apply(post, request, category);
        ApplyVariants(post, request, category);

        return await dbContext.WithOwnerLockAsync(ownerId, async () =>
        {
            if (!post.HasEnded(now))
            {
                await dbContext.EnsureRoomAsync(ownerId, null, now, cancellationToken);
            }

            dbContext.Posts.Add(post);
            await dbContext.SaveChangesAsync(cancellationToken);
            return await ReloadAsync(post.Id, ownerId, now, cancellationToken);
        }, cancellationToken);
    }

    public async Task<MarketplacePostDto> Handle(UpdateMarketplacePostCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var now = clock.GetUtcNow();
        var post = await dbContext.OwnedPostAsync(request.Id, ownerId, cancellationToken);
        if (post.IsFinal)
        {
            throw new DomainException("A closed or sold post cannot be changed.");
        }

        var category = await CheckedCategoryAsync(request, now, cancellationToken);
        Apply(post, request, category);
        ApplyVariants(post, request, category);

        return await dbContext.WithOwnerLockAsync(ownerId, async () =>
        {
            // An edit can bring an ended post back (a new end time): then it needs a slot again.
            if (post.Status == MarketplacePostStatus.Active && !post.HasEnded(now))
            {
                await dbContext.EnsureRoomAsync(ownerId, post.Id, now, cancellationToken);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            return await ReloadAsync(post.Id, ownerId, now, cancellationToken);
        }, cancellationToken);
    }

    /// <summary>The category, after every rule that depends on it and on the district has passed.</summary>
    private async Task<MarketplaceCategory> CheckedCategoryAsync(
        MarketplacePostFields request, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var categories = await reference.CategoriesAsync(cancellationToken);
        var category = categories.FirstOrDefault(c => c.Id == request.CategoryId && c.IsActive)
            ?? throw new ValidationException([new ValidationFailure(nameof(request.CategoryId), "Choose an available category.")]);

        if (!await dbContext.Districts.AnyAsync(d => d.Id == request.DistrictId, cancellationToken))
        {
            throw new ValidationException([new ValidationFailure(nameof(request.DistrictId), "Choose a district from the list.")]);
        }

        MarketplacePostRules.AcceptLegacyCondition(category, request);
        MarketplacePostRules.AcceptSwitchedOffDetails(category, request);
        var failures = MarketplacePostRules.Check(category, request, now, settings.Value);
        if (failures.Count != 0)
        {
            throw new ValidationException(failures);
        }

        if (category.TracksStock && !request.DeliversEverywhere)
        {
            await CheckShipsToAsync(request, cancellationToken);
        }

        return category;
    }

    /// <summary>
    /// A state, and any of its districts. An older app sends only districts: their one state is
    /// taken as the state.
    /// </summary>
    private async Task CheckShipsToAsync(MarketplacePostFields request, CancellationToken cancellationToken)
    {
        static ValidationException Refused(string property, string message) =>
            new([new ValidationFailure(property, message)]);

        var wanted = request.DeliveryDistrictIds.Distinct().ToList();
        var districtStates = await dbContext.Districts
            .Where(d => wanted.Contains(d.Id))
            .Select(d => d.StateId)
            .ToListAsync(cancellationToken);
        if (districtStates.Count != wanted.Count)
        {
            throw Refused(nameof(request.DeliveryDistrictIds), "Choose the districts it ships to from the list.");
        }

        var states = districtStates.Distinct().ToList();
        request.DeliveryStateId ??= states.Count == 1 ? states[0] : null;
        var stateId = request.DeliveryStateId
            ?? throw Refused(nameof(request.DeliveryStateId), "Choose the state it ships in, or ship all over India.");

        var state = await dbContext.States.Where(s => s.Id == stateId).Select(s => s.Name).FirstOrDefaultAsync(cancellationToken)
            ?? throw Refused(nameof(request.DeliveryStateId), "Choose the state it ships in from the list.");
        if (states.Any(s => s != stateId))
        {
            throw Refused(nameof(request.DeliveryDistrictIds), $"Choose districts in {state}.");
        }
    }

    /// <summary>
    /// A new product's colours and sizes: one sent with an id updates that row, a row not sent any more
    /// is removed, the rest are added. With any, the post's stock is theirs added up.
    /// </summary>
    private void ApplyVariants(MarketplacePost post, MarketplacePostFields request, MarketplaceCategory category)
    {
        var wanted = post.KeepsStock && category.TracksStock ? request.Variants : [];
        var kept = wanted.Where(v => v.Id is not null).Select(v => v.Id!.Value).ToHashSet();
        foreach (var gone in post.Variants.Where(v => !kept.Contains(v.Id)).ToList())
        {
            post.Variants.Remove(gone);
            dbContext.PostVariants.Remove(gone);
        }

        short order = 0;
        foreach (var input in wanted)
        {
            var variant = post.Variants.FirstOrDefault(v => v.Id == input.Id);
            if (variant is null)
            {
                // Added through the set: with its key preset, one found only on the collection would
                // be taken for a row that is already there.
                variant = new MarketplacePostVariant { PostId = post.Id, Post = post };
                dbContext.PostVariants.Add(variant);
                post.Variants.AddIfMissing(variant);
            }

            variant.Colour = Clean(input.Colour);
            variant.Size = Clean(input.Size);
            variant.Price = input.Price;
            variant.Stock = input.Stock;
            variant.SortOrder = order++;
        }

        if (wanted.Count != 0)
        {
            // Its stock is theirs added up; its price is the lowest they sell at ("from ₹449").
            post.Quantity = wanted.Sum(v => v.Stock);
            post.Price = MarketplacePostRules.VariantPrices(request).Min();
        }
    }

    private static void Apply(MarketplacePost post, MarketplacePostFields request, MarketplaceCategory category)
    {
        var kind = category.Kind;
        post.CategoryId = category.Id;
        post.SubCategoryId = MarketplacePostRules.SubCategoryOf(category, request);
        post.Kind = kind;
        post.Title = request.Title.Trim();
        post.Description = Clean(request.Description);
        post.Price = request.Price;
        post.PriceUnit = Clean(request.PriceUnit);
        post.TradeType = MarketplacePostRules.TradeTypeOf(category, request);
        post.MinOrderQuantity = post.TradeType == MarketplaceTradeType.Wholesale ? request.MinOrderQuantity : null;
        post.Condition = MarketplacePostRules.ConditionOf(category, request);
        post.Quantity = post.Condition == MarketplaceItemCondition.Used ? null : request.Quantity;
        post.PackQuantity = category.TracksStock ? request.PackQuantity ?? 1 : null;
        // A food offer's usual price, or a product's MRP.
        post.OriginalPrice = kind == MarketplacePostKind.FoodOffer || category.TracksStock ? request.OriginalPrice : null;
        post.StartsAt = kind == MarketplacePostKind.Listing ? null : request.StartsAt;
        post.EndsAt = kind == MarketplacePostKind.Listing ? null : request.EndsAt;
        post.ContactPhone = kind == MarketplacePostKind.Advertisement ? Clean(request.ContactPhone) : null;
        post.DistrictId = request.DistrictId;
        post.Area = Clean(request.Area);
        post.Latitude = request.Latitude;
        post.Longitude = request.Longitude;
        post.Attributes = MarketplacePostRules.Attributes(category, request);
        post.CustomDetails = request.CustomDetails
            .Where(d => !string.IsNullOrWhiteSpace(d.Name) && !string.IsNullOrWhiteSpace(d.Value))
            .Select(d => new MarketplacePostAttribute { Key = d.Name.Trim(), Value = d.Value.Trim() })
            .ToList();
        post.DeliversEverywhere = !category.TracksStock || request.DeliversEverywhere;
        post.DeliveryStateId = post.DeliversEverywhere ? null : request.DeliveryStateId;
        post.DeliveryDistrictIds = post.DeliversEverywhere ? [] : request.DeliveryDistrictIds.Distinct().ToList();
    }

    private async Task<MarketplacePostDto> ReloadAsync(Guid postId, Guid ownerId, DateTimeOffset now, CancellationToken cancellationToken)
    {
        var post = await dbContext.OwnedPostAsync(postId, ownerId, cancellationToken);
        return post.ToDto(now, await reference.TransitionsAsync(cancellationToken));
    }

    private static string? Clean(string? text) => string.IsNullOrWhiteSpace(text) ? null : text.Trim();
}

/// <summary>
/// The rules a post's category sets: its own required details, and those of its kind — a food offer
/// cheaper than usual and short-lived, an advertisement with a run of dates, wholesale only where the
/// category allows it. Pure, so every rule is tested without a database.
/// </summary>
public static class MarketplacePostRules
{
    /// <summary>What the business asked for: Retail unless it sent Wholesale.</summary>
    public static MarketplaceTradeType RequestedTradeType(MarketplacePostFields request) =>
        Enum.TryParse<MarketplaceTradeType>(request.TradeType, ignoreCase: true, out var type) && Enum.IsDefined(type)
            ? type
            : MarketplaceTradeType.Retail;

    /// <summary>How the post sells: a wholesale-only category (B2B) always sells wholesale.</summary>
    public static MarketplaceTradeType TradeTypeOf(MarketplaceCategory category, MarketplacePostFields request) =>
        category.TradeMode switch
        {
            MarketplaceTradeMode.WholesaleOnly => MarketplaceTradeType.Wholesale,
            MarketplaceTradeMode.RetailOnly => MarketplaceTradeType.Retail,
            _ => RequestedTradeType(request),
        };

    /// <summary>The chosen sub-category when it is one of the category's, else null.</summary>
    public static Guid? SubCategoryOf(MarketplaceCategory category, MarketplacePostFields request) =>
        category.SubCategories.Any(s => s.Id == request.SubCategoryId && s.IsActive && !s.IsDeleted)
            ? request.SubCategoryId
            : null;

    /// <summary>New or Used as sent; null when missing or not one of them.</summary>
    /// <summary>A new product sold in colours or sizes.</summary>
    public static bool HasVariants(MarketplaceCategory category, MarketplacePostFields request) =>
        category.TracksStock && request.Variants.Count != 0 && RequestedCondition(request) == MarketplaceItemCondition.New;

    /// <summary>What each colour / size sells at — its own price, else the post's (older apps send one).</summary>
    public static List<decimal> VariantPrices(MarketplacePostFields request) =>
        [.. request.Variants.Select(v => v.Price ?? request.Price).OfType<decimal>()];

    public static MarketplaceItemCondition? RequestedCondition(MarketplacePostFields request) =>
        Enum.TryParse<MarketplaceItemCondition>(request.Condition, ignoreCase: true, out var condition) && Enum.IsDefined(condition)
            ? condition
            : null;

    /// <summary>
    /// Apps before 1.15 — an APK not yet updated, a browser tab left open — send New / Used as a
    /// detail and no stock. In a category that keeps stock, that detail becomes the condition (a new
    /// item with no count gets 1, as the upgrade gave live posts) and leaves the details, so an older
    /// app can still post.
    /// </summary>
    public static void AcceptLegacyCondition(MarketplaceCategory category, MarketplacePostFields request)
    {
        if (!category.TracksStock
            || !request.Attributes.Remove(MarketplacePost.LegacyConditionKey, out var legacy)
            || !string.IsNullOrWhiteSpace(request.Condition))
        {
            return;
        }

        request.Condition = legacy?.Trim();
        if (RequestedCondition(request) == MarketplaceItemCondition.New)
        {
            request.Quantity ??= 1;
        }
    }

    /// <summary>
    /// A detail the super admin switched off, sent by an app that still asks it (Fabric on a saree):
    /// its value becomes one of the post's own details of the same name rather than a refusal, so an
    /// older app saves and nothing it said is lost. One already named the same is kept as it is.
    /// </summary>
    public static void AcceptSwitchedOffDetails(MarketplaceCategory category, MarketplacePostFields request)
    {
        var subCategoryId = SubCategoryOf(category, request);
        var switchedOff = category.Fields
            .Where(f => !f.IsActive && !f.IsDeleted && (f.SubCategoryId is null || f.SubCategoryId == subCategoryId))
            .DistinctBy(f => f.Key, StringComparer.Ordinal)
            .Where(f => !FieldsFor(category, request).Any(asked => asked.Key == f.Key))
            .ToList();
        foreach (var field in switchedOff)
        {
            if (!request.Attributes.Remove(field.Key, out var value) || string.IsNullOrWhiteSpace(value))
            {
                continue;
            }

            if (!request.CustomDetails.Any(d => string.Equals(d.Name.Trim(), field.Label, StringComparison.OrdinalIgnoreCase)))
            {
                request.CustomDetails.Add(new MarketplaceCustomDetailInput { Name = field.Label, Value = value.Trim() });
            }
        }
    }

    /// <summary>The post's condition: only a category that keeps stock has one.</summary>
    public static MarketplaceItemCondition? ConditionOf(MarketplaceCategory category, MarketplacePostFields request) =>
        category.TracksStock ? RequestedCondition(request) : null;

    /// <summary>The details a post in this category and sub-category is asked, in form order.</summary>
    public static IEnumerable<MarketplaceCategoryField> FieldsFor(MarketplaceCategory category, MarketplacePostFields request)
    {
        var subCategoryId = SubCategoryOf(category, request);
        return category.Fields
            .Where(f => f.AppliesTo(subCategoryId))
            .OrderBy(f => f.SubCategoryId is null ? 0 : 1)
            .ThenBy(f => f.DisplayOrder)
            .DistinctBy(f => f.Key, StringComparer.Ordinal);
    }

    public static List<ValidationFailure> Check(
        MarketplaceCategory category, MarketplacePostFields request, DateTimeOffset now, MarketplaceSettings settings)
    {
        var failures = new List<ValidationFailure>();
        void Fail(string property, string message) => failures.Add(new ValidationFailure(property, message));

        CheckSubCategory(category, request, Fail);
        CheckTrade(category, request, Fail);
        CheckStock(category, request, Fail);
        CheckProductExtras(category, request, Fail);
        CheckCustomDetails(category, request, Fail);
        switch (category.Kind)
        {
            case MarketplacePostKind.Listing:
                // A new product with colours or sizes is priced by them; anything else by its own price.
                if (HasVariants(category, request))
                {
                    if (VariantPrices(request).Count != request.Variants.Count)
                    {
                        Fail(nameof(request.Variants), "Give each colour / size its price.");
                    }
                }
                else if (request.Price is null)
                {
                    Fail(nameof(request.Price), "Enter a price.");
                }

                break;
            case MarketplacePostKind.FoodOffer:
                CheckFood(request, now, settings, Fail);
                break;
            case MarketplacePostKind.Advertisement:
                CheckWindow(request, now, settings, TimeSpan.FromDays(settings.MaxAdDays), $"{settings.MaxAdDays} days", Fail);
                break;
        }

        CheckAttributes(category, request, Fail);
        return failures;
    }

    /// <summary>The category's active fields' values, trimmed, numbers in a plain invariant form, empties dropped.</summary>
    public static List<MarketplacePostAttribute> Attributes(MarketplaceCategory category, MarketplacePostFields request) =>
        FieldsFor(category, request)
            .Select(f => (Field: f, Value: request.Attributes.GetValueOrDefault(f.Key)?.Trim()))
            .Where(x => !string.IsNullOrEmpty(x.Value))
            .Select(x => new MarketplacePostAttribute
            {
                Key = x.Field.Key,
                Value = x.Field.FieldType == MarketplaceFieldType.Number
                    ? decimal.Parse(x.Value!, NumberStyles.Number, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture)
                    : x.Value!,
            })
            .ToList();

    private static void CheckSubCategory(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        var hasAny = category.SubCategories.Any(s => s.IsActive && !s.IsDeleted);
        if (request.SubCategoryId is null)
        {
            if (hasAny)
            {
                fail(nameof(request.SubCategoryId), $"Choose what kind of {category.Name.ToLowerInvariant()} it is.");
            }

            return;
        }

        if (SubCategoryOf(category, request) is null)
        {
            fail(nameof(request.SubCategoryId), $"Choose a sub-category of {category.Name} from the list.");
        }
    }

    /// <summary>
    /// A category that keeps stock asks New or Used: a new item needs its stock (0 is allowed: out of
    /// stock), a used one is a single piece and has none. Elsewhere a quantity is at least 1.
    /// </summary>
    private static void CheckStock(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        if (!category.TracksStock)
        {
            if (request.Quantity == 0)
            {
                fail(nameof(request.Quantity), "The quantity must be at least 1.");
            }

            return;
        }

        switch (RequestedCondition(request))
        {
            case null:
                fail(nameof(request.Condition), "Choose New or Used.");
                break;
            case MarketplaceItemCondition.New when request.Quantity is null && request.Variants.Count == 0:
                fail(nameof(request.Quantity), "Enter how many you have in stock.");
                break;
        }
    }

    /// <summary>
    /// What only a product in a category that keeps stock may have: colours and sizes (a new one
    /// only), an MRP no lower than the price, and where it ships.
    /// </summary>
    private static void CheckProductExtras(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        var isNewProduct = category.TracksStock && RequestedCondition(request) == MarketplaceItemCondition.New;
        if (request.Variants.Count != 0)
        {
            if (!isNewProduct)
            {
                fail(nameof(request.Variants), "Only a new product has colours and sizes, each with its stock.");
            }
            else if (request.Variants
                .GroupBy(v => (Colour: Key(v.Colour), Size: Key(v.Size)))
                .FirstOrDefault(g => g.Count() > 1) is { } twice)
            {
                fail(nameof(request.Variants), $"{VariantName(twice.First())} is listed twice.");
            }
        }

        // The MRP is above every price it is sold at: each colour / size's, or the one price.
        var prices = HasVariants(category, request) ? VariantPrices(request) : [.. request.Price is { } one ? [one] : Array.Empty<decimal>()];
        if (category.TracksStock && request.OriginalPrice is { } mrp && prices.Count != 0 && mrp < prices.Max())
        {
            fail(nameof(request.OriginalPrice), "The MRP cannot be less than the price.");
        }

        if (category.TracksStock && !request.DeliversEverywhere && request.DeliveryStateId is null && request.DeliveryDistrictIds.Count == 0)
        {
            fail(nameof(request.DeliveryStateId), "Choose the state it ships in, or ship all over India.");
        }
    }

    /// <summary>The business's own details: each named once, and not one the category already asks.</summary>
    private static void CheckCustomDetails(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        var asked = FieldsFor(category, request).Select(f => Key(f.Label)).ToHashSet();
        var seen = new HashSet<string>();
        foreach (var detail in request.CustomDetails.Where(d => !string.IsNullOrWhiteSpace(d.Name)))
        {
            var name = Key(detail.Name);
            if (asked.Contains(name))
            {
                fail(nameof(request.CustomDetails), $"{detail.Name.Trim()} is already asked above.");
            }
            else if (!seen.Add(name))
            {
                fail(nameof(request.CustomDetails), $"{detail.Name.Trim()} is added twice.");
            }
        }
    }

    /// <summary>"Red · M" for a message.</summary>
    public static string VariantName(MarketplaceVariantInput variant) =>
        string.Join(" · ", new[] { variant.Colour?.Trim(), variant.Size?.Trim() }.Where(p => !string.IsNullOrEmpty(p)));

    private static string Key(string? text) => (text ?? string.Empty).Trim().ToUpperInvariant();

    private static void CheckTrade(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        if (category.TradeMode == MarketplaceTradeMode.RetailOnly && RequestedTradeType(request) == MarketplaceTradeType.Wholesale)
        {
            fail(nameof(request.TradeType), $"{category.Name} does not take wholesale posts.");
            return;
        }

        if (TradeTypeOf(category, request) != MarketplaceTradeType.Wholesale)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(request.PriceUnit))
        {
            fail(nameof(request.PriceUnit), "Enter what the price is per, e.g. kg.");
        }

        if (request.MinOrderQuantity is null)
        {
            fail(nameof(request.MinOrderQuantity), "Enter the smallest order for wholesale.");
        }
        else if (request.Quantity is { } quantity && request.MinOrderQuantity > quantity)
        {
            fail(nameof(request.MinOrderQuantity), "The smallest order cannot be more than the quantity for sale.");
        }
    }

    private static void CheckFood(MarketplacePostFields request, DateTimeOffset now, MarketplaceSettings settings, Action<string, string> fail)
    {
        if (request.Price is null)
        {
            fail(nameof(request.Price), "Enter the offer price.");
        }

        if (request.OriginalPrice is null)
        {
            fail(nameof(request.OriginalPrice), "Enter the usual price.");
        }
        else if (request.Price is { } price && price >= request.OriginalPrice)
        {
            fail(nameof(request.Price), "The offer price must be less than the usual price.");
        }

        if (request.Quantity is null)
        {
            fail(nameof(request.Quantity), "Enter how many portions are on offer.");
        }

        CheckWindow(request, now, settings, TimeSpan.FromHours(settings.MaxFoodOfferHours), $"{settings.MaxFoodOfferHours} hours", fail);
    }

    private static void CheckWindow(
        MarketplacePostFields request, DateTimeOffset now, MarketplaceSettings settings, TimeSpan longest, string longestText, Action<string, string> fail)
    {
        if (request.StartsAt is not { } start || request.EndsAt is not { } end)
        {
            fail(nameof(request.EndsAt), "Enter when it starts and ends.");
            return;
        }

        if (end <= start)
        {
            fail(nameof(request.EndsAt), "The end must be after the start.");
        }
        else if (end - start > longest)
        {
            fail(nameof(request.EndsAt), $"It can run for at most {longestText}.");
        }

        if (start > now.AddDays(settings.MaxStartDaysAhead))
        {
            fail(nameof(request.StartsAt), $"It can start at most {settings.MaxStartDaysAhead} days ahead.");
        }

        if (end <= now)
        {
            fail(nameof(request.EndsAt), "The end must be in the future.");
        }
    }

    private static void CheckAttributes(MarketplaceCategory category, MarketplacePostFields request, Action<string, string> fail)
    {
        var fields = FieldsFor(category, request).ToDictionary(f => f.Key, StringComparer.Ordinal);
        foreach (var key in request.Attributes.Keys.Where(k => !fields.ContainsKey(k)))
        {
            fail($"Attributes.{key}", $"{category.Name} has no detail called '{key}'.");
        }

        foreach (var field in fields.Values)
        {
            var value = request.Attributes.GetValueOrDefault(field.Key)?.Trim();
            var property = $"Attributes.{field.Key}";
            if (string.IsNullOrEmpty(value))
            {
                if (field.IsRequired)
                {
                    fail(property, $"{field.Label} is required.");
                }

                continue;
            }

            if (field.FieldType == MarketplaceFieldType.Number
                && !decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out _))
            {
                fail(property, $"{field.Label} must be a number.");
            }
            else if (field.FieldType == MarketplaceFieldType.Select && !field.Options.Contains(value, StringComparer.Ordinal))
            {
                fail(property, $"Choose {field.Label} from the list.");
            }
        }
    }
}
