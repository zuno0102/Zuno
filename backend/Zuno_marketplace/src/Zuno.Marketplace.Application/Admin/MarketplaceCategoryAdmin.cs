using System.Text.RegularExpressions;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Categories;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Admin;

/// <summary>A main category as the super admin edits it. Switching it off is how it is removed.</summary>
public abstract class MarketplaceCategoryFields
{
    public string Name { get; set; } = string.Empty;

    /// <summary>The few letters the category squares show, e.g. "B2B"; empty shows the name.</summary>
    public string? ShortName { get; set; }

    /// <summary>What goes in it, shown in the post form's picker, e.g. "Sarees, shirts, toys".</summary>
    public string? Description { get; set; }

    public string? IconName { get; set; }

    /// <summary><c>Listing</c>, <c>FoodOffer</c> or <c>Advertisement</c>.</summary>
    public string Kind { get; set; } = nameof(MarketplacePostKind.Listing);

    /// <summary><c>RetailOnly</c>, <c>WholesaleOnly</c> or <c>Either</c>.</summary>
    public string TradeMode { get; set; } = nameof(MarketplaceTradeMode.RetailOnly);

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

public class CreateMarketplaceCategoryCommand : MarketplaceCategoryFields, IRequest<MarketplaceCategoryDto>;

public class UpdateMarketplaceCategoryCommand : MarketplaceCategoryFields, IRequest<MarketplaceCategoryDto>
{
    public Guid Id { get; set; }
}

/// <summary>A sub-category as the super admin edits it, e.g. "Sarees" under Products.</summary>
public abstract class MarketplaceSubCategoryFields
{
    public Guid CategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? IconName { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

public class CreateMarketplaceSubCategoryCommand : MarketplaceSubCategoryFields, IRequest<MarketplaceCategoryDto>;

public class UpdateMarketplaceSubCategoryCommand : MarketplaceSubCategoryFields, IRequest<MarketplaceCategoryDto>
{
    public Guid Id { get; set; }
}

/// <summary>A detail a category asks for, as the super admin edits it.</summary>
public abstract class MarketplaceFieldFields
{
    public Guid CategoryId { get; set; }

    /// <summary>Ask it only under this sub-category; null asks it everywhere in the category.</summary>
    public Guid? SubCategoryId { get; set; }

    public string Label { get; set; } = string.Empty;

    /// <summary><c>Text</c>, <c>Number</c> or <c>Select</c>.</summary>
    public string FieldType { get; set; } = nameof(MarketplaceFieldType.Text);

    /// <summary>The choices of a Select field.</summary>
    public List<string> Options { get; set; } = [];

    public string? Unit { get; set; }

    public bool IsRequired { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

/// <summary>Adds a detail. Its key is made from the label once and never changes, so saved values keep their meaning.</summary>
public class CreateMarketplaceFieldCommand : MarketplaceFieldFields, IRequest<MarketplaceCategoryDto>;

public class UpdateMarketplaceFieldCommand : MarketplaceFieldFields, IRequest<MarketplaceCategoryDto>
{
    public Guid Id { get; set; }
}

public abstract class MarketplaceCategoryFieldsValidator<T> : AbstractValidator<T>
    where T : MarketplaceCategoryFields
{
    protected MarketplaceCategoryFieldsValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100).Matches("[A-Za-z0-9]").WithMessage("Name must have a letter or digit.");
        RuleFor(x => x.ShortName).MaximumLength(20);
        RuleFor(x => x.Description).MaximumLength(200);
        RuleFor(x => x.IconName).MaximumLength(50);
        RuleFor(x => x.Kind)
            .Must(k => Enum.TryParse<MarketplacePostKind>(k, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Kind must be Listing, FoodOffer or Advertisement.");
        RuleFor(x => x.TradeMode)
            .Must(t => Enum.TryParse<MarketplaceTradeMode>(t, true, out var v) && Enum.IsDefined(v))
            .WithMessage("How it sells must be RetailOnly, WholesaleOnly or Either.");
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
    }
}

public class CreateMarketplaceCategoryCommandValidator : MarketplaceCategoryFieldsValidator<CreateMarketplaceCategoryCommand>;

public class UpdateMarketplaceCategoryCommandValidator : MarketplaceCategoryFieldsValidator<UpdateMarketplaceCategoryCommand>
{
    public UpdateMarketplaceCategoryCommandValidator() => RuleFor(x => x.Id).NotEmpty();
}

public abstract class MarketplaceSubCategoryFieldsValidator<T> : AbstractValidator<T>
    where T : MarketplaceSubCategoryFields
{
    protected MarketplaceSubCategoryFieldsValidator()
    {
        RuleFor(x => x.CategoryId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100).Matches("[A-Za-z0-9]").WithMessage("Name must have a letter or digit.");
        RuleFor(x => x.IconName).MaximumLength(50);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
    }
}

public class CreateMarketplaceSubCategoryCommandValidator : MarketplaceSubCategoryFieldsValidator<CreateMarketplaceSubCategoryCommand>;

public class UpdateMarketplaceSubCategoryCommandValidator : MarketplaceSubCategoryFieldsValidator<UpdateMarketplaceSubCategoryCommand>
{
    public UpdateMarketplaceSubCategoryCommandValidator() => RuleFor(x => x.Id).NotEmpty();
}

public abstract class MarketplaceFieldFieldsValidator<T> : AbstractValidator<T>
    where T : MarketplaceFieldFields
{
    public const int MaxOptions = 50;

    protected MarketplaceFieldFieldsValidator()
    {
        RuleFor(x => x.CategoryId).NotEmpty();
        RuleFor(x => x.Label).NotEmpty().MaximumLength(60).Matches("[A-Za-z0-9]").WithMessage("Label must have a letter or digit.");
        RuleFor(x => x.Unit).MaximumLength(20);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
        RuleFor(x => x.FieldType)
            .Must(t => Enum.TryParse<MarketplaceFieldType>(t, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Field type must be Text, Number or Select.");
        RuleFor(x => x.Options.Count).LessThanOrEqualTo(MaxOptions).OverridePropertyName(nameof(MarketplaceFieldFields.Options));
        RuleForEach(x => x.Options).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Options)
            .Must(o => o.Count > 0 && o.Distinct(StringComparer.OrdinalIgnoreCase).Count() == o.Count)
            .When(x => string.Equals(x.FieldType, nameof(MarketplaceFieldType.Select), StringComparison.OrdinalIgnoreCase))
            .WithMessage("A list needs at least one choice, each different.");
    }
}

public class CreateMarketplaceFieldCommandValidator : MarketplaceFieldFieldsValidator<CreateMarketplaceFieldCommand>;

public class UpdateMarketplaceFieldCommandValidator : MarketplaceFieldFieldsValidator<UpdateMarketplaceFieldCommand>
{
    public UpdateMarketplaceFieldCommandValidator() => RuleFor(x => x.Id).NotEmpty();
}

/// <summary>The super admin's category, sub-category and detail edits. Every save clears the cached category list.</summary>
public partial class MarketplaceCategoryAdminHandlers(IMarketplaceDbContext dbContext, MarketplaceReference reference) :
    IRequestHandler<CreateMarketplaceCategoryCommand, MarketplaceCategoryDto>,
    IRequestHandler<UpdateMarketplaceCategoryCommand, MarketplaceCategoryDto>,
    IRequestHandler<CreateMarketplaceSubCategoryCommand, MarketplaceCategoryDto>,
    IRequestHandler<UpdateMarketplaceSubCategoryCommand, MarketplaceCategoryDto>,
    IRequestHandler<CreateMarketplaceFieldCommand, MarketplaceCategoryDto>,
    IRequestHandler<UpdateMarketplaceFieldCommand, MarketplaceCategoryDto>
{
    public async Task<MarketplaceCategoryDto> Handle(CreateMarketplaceCategoryCommand request, CancellationToken cancellationToken)
    {
        var slug = Slug(request.Name, '-');
        await EnsureUniqueSlugAsync(slug, null, cancellationToken);

        var category = new MarketplaceCategory { Slug = slug };
        Apply(category, request);
        dbContext.Categories.Add(category);
        return await SaveAsync(category.Id, cancellationToken);
    }

    public async Task<MarketplaceCategoryDto> Handle(UpdateMarketplaceCategoryCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.Id, cancellationToken);
        var slug = Slug(request.Name, '-');
        await EnsureUniqueSlugAsync(slug, category.Id, cancellationToken);

        category.Slug = slug;
        Apply(category, request);
        return await SaveAsync(category.Id, cancellationToken);
    }

    public async Task<MarketplaceCategoryDto> Handle(CreateMarketplaceSubCategoryCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var slug = Slug(request.Name, '-');
        EnsureUniqueSubSlug(category, slug, null);

        var sub = new MarketplaceSubCategory { CategoryId = category.Id, Slug = slug };
        Apply(sub, request);
        dbContext.SubCategories.Add(sub);
        return await SaveAsync(category.Id, cancellationToken);
    }

    public async Task<MarketplaceCategoryDto> Handle(UpdateMarketplaceSubCategoryCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var sub = category.SubCategories.FirstOrDefault(s => s.Id == request.Id)
            ?? throw new EntityNotFoundException("Sub-category", request.Id);
        var slug = Slug(request.Name, '-');
        EnsureUniqueSubSlug(category, slug, sub.Id);

        sub.Slug = slug;
        Apply(sub, request);
        return await SaveAsync(category.Id, cancellationToken);
    }

    public async Task<MarketplaceCategoryDto> Handle(CreateMarketplaceFieldCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        EnsureSubCategoryOf(category, request.SubCategoryId);
        var key = Slug(request.Label, '_');
        EnsureKeyIsFree(category, key, request.SubCategoryId, null, request.Label);

        var field = new MarketplaceCategoryField { CategoryId = category.Id, Key = key };
        Apply(field, request);
        dbContext.CategoryFields.Add(field);
        return await SaveAsync(category.Id, cancellationToken);
    }

    public async Task<MarketplaceCategoryDto> Handle(UpdateMarketplaceFieldCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var field = category.Fields.FirstOrDefault(f => f.Id == request.Id)
            ?? throw new EntityNotFoundException("Category field", request.Id);
        EnsureSubCategoryOf(category, request.SubCategoryId);
        EnsureKeyIsFree(category, field.Key, request.SubCategoryId, field.Id, request.Label);

        Apply(field, request);
        return await SaveAsync(category.Id, cancellationToken);
    }

    private static void Apply(MarketplaceCategory category, MarketplaceCategoryFields request)
    {
        category.Name = request.Name.Trim();
        category.ShortName = Clean(request.ShortName);
        category.Description = Clean(request.Description);
        category.IconName = Clean(request.IconName);
        category.Kind = Enum.Parse<MarketplacePostKind>(request.Kind, ignoreCase: true);
        category.TradeMode = Enum.Parse<MarketplaceTradeMode>(request.TradeMode, ignoreCase: true);
        category.DisplayOrder = request.DisplayOrder;
        category.IsActive = request.IsActive;
    }

    private static void Apply(MarketplaceSubCategory sub, MarketplaceSubCategoryFields request)
    {
        sub.Name = request.Name.Trim();
        sub.IconName = Clean(request.IconName);
        sub.DisplayOrder = request.DisplayOrder;
        sub.IsActive = request.IsActive;
    }

    private static void Apply(MarketplaceCategoryField field, MarketplaceFieldFields request)
    {
        field.SubCategoryId = request.SubCategoryId;
        field.Label = request.Label.Trim();
        field.FieldType = Enum.Parse<MarketplaceFieldType>(request.FieldType, ignoreCase: true);
        field.Options = field.FieldType == MarketplaceFieldType.Select ? request.Options.Select(o => o.Trim()).ToList() : [];
        field.Unit = Clean(request.Unit);
        field.IsRequired = request.IsRequired;
        field.DisplayOrder = request.DisplayOrder;
        field.IsActive = request.IsActive;
    }

    private static string? Clean(string? text) => string.IsNullOrWhiteSpace(text) ? null : text.Trim();

    private async Task<MarketplaceCategory> CategoryAsync(Guid id, CancellationToken cancellationToken) =>
        await dbContext.Categories
            .Include(c => c.SubCategories)
            .Include(c => c.Fields)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken)
            ?? throw new EntityNotFoundException("Category", id);

    private async Task EnsureUniqueSlugAsync(string slug, Guid? exceptId, CancellationToken cancellationToken)
    {
        if (await dbContext.Categories.AnyAsync(c => c.Slug == slug && c.Id != exceptId, cancellationToken))
        {
            throw new DomainException("A category with this name already exists.");
        }
    }

    private static void EnsureUniqueSubSlug(MarketplaceCategory category, string slug, Guid? exceptId)
    {
        if (category.SubCategories.Any(s => s.Slug == slug && s.Id != exceptId && !s.IsDeleted))
        {
            throw new DomainException($"{category.Name} already has a sub-category with this name.");
        }
    }

    private static void EnsureSubCategoryOf(MarketplaceCategory category, Guid? subCategoryId)
    {
        if (subCategoryId is { } id && !category.SubCategories.Any(s => s.Id == id && !s.IsDeleted))
        {
            throw new EntityNotFoundException("Sub-category", id);
        }
    }

    /// <summary>
    /// A post sees the category's own details and its sub-category's together, so one key may not be
    /// asked twice there: a category-wide detail clashes with every sub-category's, a sub-category's
    /// only with the category-wide ones and its own.
    /// </summary>
    private static void EnsureKeyIsFree(MarketplaceCategory category, string key, Guid? subCategoryId, Guid? exceptId, string label)
    {
        var clash = category.Fields.Any(f =>
            f.Key == key
            && f.Id != exceptId
            && !f.IsDeleted
            && (subCategoryId is null || f.SubCategoryId is null || f.SubCategoryId == subCategoryId));
        if (clash)
        {
            throw new DomainException($"{category.Name} already asks a detail called '{label}' there.");
        }
    }

    private async Task<MarketplaceCategoryDto> SaveAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        await dbContext.SaveChangesAsync(cancellationToken);
        reference.ForgetCategories();

        var category = await dbContext.Categories.AsNoTracking()
            .Include(c => c.SubCategories)
            .Include(c => c.Fields)
            .FirstAsync(c => c.Id == categoryId, cancellationToken);
        return category.ToDto(includeInactive: true);
    }

    /// <summary>"Farm &amp; Wholesale" → <c>farm-wholesale</c>; "KM driven" → <c>km_driven</c>.</summary>
    internal static string Slug(string text, char separator) =>
        NonWord().Replace(text.Trim().ToLowerInvariant(), separator.ToString()).Trim(separator);

    [GeneratedRegex("[^a-z0-9]+")]
    private static partial Regex NonWord();
}
