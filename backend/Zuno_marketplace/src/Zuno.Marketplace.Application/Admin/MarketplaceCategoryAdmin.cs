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

/// <summary>A category as the super admin edits it. Switching it off is how it is removed.</summary>
public abstract class MarketplaceCategoryFields
{
    public string Name { get; set; } = string.Empty;

    public string? IconName { get; set; }

    /// <summary><c>Listing</c>, <c>FoodOffer</c> or <c>Advertisement</c>.</summary>
    public string Kind { get; set; } = nameof(MarketplacePostKind.Listing);

    public bool AllowsWholesale { get; set; }

    public short DisplayOrder { get; set; }

    public bool IsActive { get; set; } = true;
}

public class CreateMarketplaceCategoryCommand : MarketplaceCategoryFields, IRequest<MarketplaceCategoryDto>;

public class UpdateMarketplaceCategoryCommand : MarketplaceCategoryFields, IRequest<MarketplaceCategoryDto>
{
    public Guid Id { get; set; }
}

/// <summary>A detail a category asks for, as the super admin edits it.</summary>
public abstract class MarketplaceFieldFields
{
    public Guid CategoryId { get; set; }

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
        RuleFor(x => x.IconName).MaximumLength(50);
        RuleFor(x => x.Kind)
            .Must(k => Enum.TryParse<MarketplacePostKind>(k, true, out var v) && Enum.IsDefined(v))
            .WithMessage("Kind must be Listing, FoodOffer or Advertisement.");
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo((short)0);
    }
}

public class CreateMarketplaceCategoryCommandValidator : MarketplaceCategoryFieldsValidator<CreateMarketplaceCategoryCommand>;

public class UpdateMarketplaceCategoryCommandValidator : MarketplaceCategoryFieldsValidator<UpdateMarketplaceCategoryCommand>
{
    public UpdateMarketplaceCategoryCommandValidator() => RuleFor(x => x.Id).NotEmpty();
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

/// <summary>The super admin's category and field edits. Every save clears the cached category list.</summary>
public partial class MarketplaceCategoryAdminHandlers(IMarketplaceDbContext dbContext, MarketplaceReference reference) :
    IRequestHandler<CreateMarketplaceCategoryCommand, MarketplaceCategoryDto>,
    IRequestHandler<UpdateMarketplaceCategoryCommand, MarketplaceCategoryDto>,
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

    public async Task<MarketplaceCategoryDto> Handle(CreateMarketplaceFieldCommand request, CancellationToken cancellationToken)
    {
        var category = await CategoryAsync(request.CategoryId, cancellationToken);
        var key = Slug(request.Label, '_');
        if (category.Fields.Any(f => f.Key == key))
        {
            throw new DomainException($"{category.Name} already has a detail called '{request.Label}'.");
        }

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

        Apply(field, request);
        return await SaveAsync(category.Id, cancellationToken);
    }

    private static void Apply(MarketplaceCategory category, MarketplaceCategoryFields request)
    {
        category.Name = request.Name.Trim();
        category.IconName = string.IsNullOrWhiteSpace(request.IconName) ? null : request.IconName.Trim();
        category.Kind = Enum.Parse<MarketplacePostKind>(request.Kind, ignoreCase: true);
        category.AllowsWholesale = request.AllowsWholesale;
        category.DisplayOrder = request.DisplayOrder;
        category.IsActive = request.IsActive;
    }

    private static void Apply(MarketplaceCategoryField field, MarketplaceFieldFields request)
    {
        field.Label = request.Label.Trim();
        field.FieldType = Enum.Parse<MarketplaceFieldType>(request.FieldType, ignoreCase: true);
        field.Options = field.FieldType == MarketplaceFieldType.Select ? request.Options.Select(o => o.Trim()).ToList() : [];
        field.Unit = string.IsNullOrWhiteSpace(request.Unit) ? null : request.Unit.Trim();
        field.IsRequired = request.IsRequired;
        field.DisplayOrder = request.DisplayOrder;
        field.IsActive = request.IsActive;
    }

    private async Task<MarketplaceCategory> CategoryAsync(Guid id, CancellationToken cancellationToken) =>
        await dbContext.Categories.Include(c => c.Fields).FirstOrDefaultAsync(c => c.Id == id, cancellationToken)
            ?? throw new EntityNotFoundException("Category", id);

    private async Task EnsureUniqueSlugAsync(string slug, Guid? exceptId, CancellationToken cancellationToken)
    {
        if (await dbContext.Categories.AnyAsync(c => c.Slug == slug && c.Id != exceptId, cancellationToken))
        {
            throw new DomainException("A category with this name already exists.");
        }
    }

    private async Task<MarketplaceCategoryDto> SaveAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        await dbContext.SaveChangesAsync(cancellationToken);
        reference.ForgetCategories();

        var category = await dbContext.Categories.AsNoTracking().Include(c => c.Fields)
            .FirstAsync(c => c.Id == categoryId, cancellationToken);
        return category.ToDto(includeInactiveFields: true);
    }

    /// <summary>"Farm &amp; Wholesale" → <c>farm-wholesale</c>; "KM driven" → <c>km_driven</c>.</summary>
    internal static string Slug(string text, char separator) =>
        NonWord().Replace(text.Trim().ToLowerInvariant(), separator.ToString()).Trim(separator);

    [GeneratedRegex("[^a-z0-9]+")]
    private static partial Regex NonWord();
}
