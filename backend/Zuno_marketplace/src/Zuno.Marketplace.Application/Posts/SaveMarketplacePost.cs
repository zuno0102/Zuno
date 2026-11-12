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

    public int? Quantity { get; set; }

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
    public const int TitleMax = 120;
    public const int DescriptionMax = 2000;
    public const int UnitMax = 20;
    public const int AreaMax = 120;
    public const int AttributeValueMax = 200;
    public const int MaxAttributes = 30;

    protected MarketplacePostFieldsValidator(IOptions<MarketplaceSettings> settings)
    {
        var limits = settings.Value;
        RuleFor(x => x.CategoryId).NotEmpty();
        RuleFor(x => x.DistrictId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(TitleMax);
        RuleFor(x => x.Description).MaximumLength(DescriptionMax);
        RuleFor(x => x.PriceUnit).MaximumLength(UnitMax);
        RuleFor(x => x.Area).MaximumLength(AreaMax);
        RuleFor(x => x.Price).GreaterThan(0).LessThanOrEqualTo(limits.MaxPrice).When(x => x.Price.HasValue);
        RuleFor(x => x.OriginalPrice).GreaterThan(0).LessThanOrEqualTo(limits.MaxPrice).When(x => x.OriginalPrice.HasValue);
        RuleFor(x => x.Quantity).InclusiveBetween(1, limits.MaxQuantity).When(x => x.Quantity.HasValue);
        RuleFor(x => x.MinOrderQuantity).InclusiveBetween(1, limits.MaxQuantity).When(x => x.MinOrderQuantity.HasValue);
        RuleFor(x => x.TradeType)
            .Must(t => string.IsNullOrEmpty(t) || Enum.TryParse<MarketplaceTradeType>(t, ignoreCase: true, out var parsed) && Enum.IsDefined(parsed))
            .WithMessage("Trade type must be Retail or Wholesale.");
        RuleFor(x => x.ContactPhone).Matches(@"^\+?[0-9]{10,15}$").When(x => !string.IsNullOrEmpty(x.ContactPhone))
            .WithMessage("Contact phone must be 10 to 15 digits.");
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90).When(x => x.Latitude.HasValue);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180).When(x => x.Longitude.HasValue);
        RuleFor(x => x).Must(x => x.Latitude.HasValue == x.Longitude.HasValue)
            .WithName("Location").WithMessage("Send both latitude and longitude, or neither.");
        RuleFor(x => x.Attributes.Count).LessThanOrEqualTo(MaxAttributes).OverridePropertyName("Attributes");
        RuleForEach(x => x.Attributes).Must(a => (a.Value?.Length ?? 0) <= AttributeValueMax)
            .WithMessage($"Each detail must be {AttributeValueMax} characters or fewer.");
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
        if (post.Status == MarketplacePostStatus.Closed)
        {
            throw new DomainException("A closed post cannot be changed.");
        }

        var category = await CheckedCategoryAsync(request, now, cancellationToken);
        Apply(post, request, category);

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

        var failures = MarketplacePostRules.Check(category, request, now, settings.Value);
        if (failures.Count != 0)
        {
            throw new ValidationException(failures);
        }

        return category;
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
        post.Quantity = request.Quantity;
        post.OriginalPrice = kind == MarketplacePostKind.FoodOffer ? request.OriginalPrice : null;
        post.StartsAt = kind == MarketplacePostKind.Listing ? null : request.StartsAt;
        post.EndsAt = kind == MarketplacePostKind.Listing ? null : request.EndsAt;
        post.ContactPhone = kind == MarketplacePostKind.Advertisement ? Clean(request.ContactPhone) : null;
        post.DistrictId = request.DistrictId;
        post.Area = Clean(request.Area);
        post.Latitude = request.Latitude;
        post.Longitude = request.Longitude;
        post.Attributes = MarketplacePostRules.Attributes(category, request);
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
        switch (category.Kind)
        {
            case MarketplacePostKind.Listing:
                if (request.Price is null)
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
