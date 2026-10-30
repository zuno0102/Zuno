using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Common;

/// <summary>What a business fills in for a rent item — the same when adding one and when editing it.</summary>
public interface IRentalItemFields
{
    Guid RentalCategoryId { get; }

    Guid? RentalSubCategoryId { get; }

    string Name { get; }

    string? Description { get; }

    /// <summary><c>Hourly</c>, <c>Daily</c> or <c>Fixed</c>.</summary>
    string PriceType { get; }

    decimal Price { get; }

    int QuantityOwned { get; }

    /// <summary><c>None</c>, <c>PerOrder</c> or <c>PerPiece</c>; empty means no advance.</summary>
    string? AdvanceType { get; }

    /// <summary>For the whole order or for each piece; ignored when no advance is asked.</summary>
    decimal? AdvanceAmount { get; }

    bool IsAvailable { get; }

    List<Guid> DistrictIds { get; }

    /// <summary>The item's whole question set, in display order. Empty clears it.</summary>
    List<RentalQuestionInput> Questions { get; }
}

/// <summary>One box the business wants the customer to fill in.</summary>
public class RentalQuestionInput
{
    /// <summary>Null for a new question; otherwise the one being edited, kept so its answers stay linked.</summary>
    public Guid? Id { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public bool IsRequired { get; set; }
}

/// <summary>Reads the rate type the app sends.</summary>
public static class RentalPricing
{
    /// <summary>The price type, or null when it is not one a rent item can be charged by.</summary>
    public static RentalPriceType? Parse(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && !int.TryParse(value, out _)
        && Enum.TryParse<RentalPriceType>(value, ignoreCase: true, out var parsed)
        && Enum.IsDefined(parsed)
            ? parsed
            : null;

    public static string AllowedList => string.Join(", ", Enum.GetNames<RentalPriceType>());

    /// <summary>The advance type; empty is none, anything unknown is null.</summary>
    public static RentalAdvanceType? ParseAdvance(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? RentalAdvanceType.None
            : !int.TryParse(value, out _)
                && Enum.TryParse<RentalAdvanceType>(value, ignoreCase: true, out var parsed)
                && Enum.IsDefined(parsed)
                ? parsed
                : null;
}

/// <summary>
/// The rules for a rent item's fields, written once and included by both the add and the edit
/// validators. Generic, so the assembly scan does not register it on its own.
/// </summary>
public class RentalItemFieldsValidator<T> : AbstractValidator<T>
    where T : IRentalItemFields
{
    public const int NameMaxLength = 200;

    public const int DescriptionMaxLength = 1000;

    public const int QuestionMaxLength = 200;

    public RentalItemFieldsValidator(IRentDbContext dbContext, IOptions<RentSettings> settings)
    {
        var limits = settings.Value;

        RuleFor(x => x.RentalCategoryId)
            .NotEmpty()
            .WithMessage("Choose a rent category from the list.")
            .MustAsync((id, cancellationToken) =>
                dbContext.RentalCategories.AnyAsync(c => c.Id == id && c.IsActive, cancellationToken))
            .WithMessage("Choose a rent category from the list.");

        RuleFor(x => x.RentalSubCategoryId)
            .MustAsync((fields, subCategoryId, cancellationToken) =>
                dbContext.RentalSubCategories.AnyAsync(
                    s => s.Id == subCategoryId && s.RentalCategoryId == fields.RentalCategoryId && s.IsActive,
                    cancellationToken))
            .When(x => x.RentalSubCategoryId.HasValue)
            .WithMessage("Choose a sub-category that belongs to the chosen category.");

        RuleFor(x => x.Name)
            .Must(name => !string.IsNullOrWhiteSpace(name))
            .WithMessage("Give the item a name.")
            .MaximumLength(NameMaxLength);

        RuleFor(x => x.Description).MaximumLength(DescriptionMaxLength);

        // A known type that the rate-type table also still offers.
        RuleFor(x => x.PriceType)
            .Must(value => RentalPricing.Parse(value).HasValue)
            .WithMessage($"Choose how you charge: {RentalPricing.AllowedList}.")
            .DependentRules(() => RuleFor(x => x.PriceType)
                .MustAsync((value, cancellationToken) =>
                {
                    var code = RentalPricing.Parse(value)!.Value;
                    return dbContext.RentalPriceTypes.AnyAsync(p => p.Code == code && p.IsActive, cancellationToken);
                })
                .WithMessage("That way of charging is not offered any more. Choose another."));

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .WithMessage("The rate must be more than zero.")
            .LessThanOrEqualTo(limits.MaxPrice)
            .WithMessage($"The rate can be at most {limits.MaxPrice:0}.");

        // An advance the advance table still offers, with an amount when one is asked.
        RuleFor(x => x.AdvanceType)
            .Must(value => RentalPricing.ParseAdvance(value).HasValue)
            .WithMessage("Choose no advance, a fixed advance for the order, or an advance per piece.")
            .DependentRules(() => RuleFor(x => x.AdvanceType)
                .MustAsync((value, cancellationToken) =>
                {
                    var code = RentalPricing.ParseAdvance(value)!.Value;
                    return dbContext.RentalAdvanceTypes.AnyAsync(a => a.Code == code && a.IsActive, cancellationToken);
                })
                .WithMessage("That kind of advance is not offered any more. Choose another."));

        RuleFor(x => x.AdvanceAmount)
            .NotNull()
            .WithMessage("Enter the advance amount, or choose no advance.")
            .GreaterThan(0)
            .WithMessage("The advance must be more than zero.")
            .LessThanOrEqualTo(limits.MaxPrice)
            .WithMessage($"The advance can be at most {limits.MaxPrice:0}.")
            .When(x => RentalPricing.ParseAdvance(x.AdvanceType) is { } type && type != RentalAdvanceType.None);

        RuleFor(x => x.QuantityOwned)
            .GreaterThanOrEqualTo(1)
            .WithMessage("You need at least one of this item to rent it out.")
            .LessThanOrEqualTo(limits.MaxQuantityOwned)
            .WithMessage($"Quantity can be at most {limits.MaxQuantityOwned}.");

        RuleFor(x => x.DistrictIds)
            .NotEmpty()
            .WithMessage("Select at least one district where this item can be rented.")
            .Must(ids => ids.Distinct().Count() <= limits.MaxDistricts)
            .WithMessage($"Select at most {limits.MaxDistricts} districts.");

        RuleFor(x => x.DistrictIds)
            .MustAsync(async (ids, cancellationToken) =>
            {
                var distinct = ids.Distinct().ToList();
                var found = await dbContext.Districts.CountAsync(d => distinct.Contains(d.Id), cancellationToken);
                return found == distinct.Count;
            })
            .When(x => x.DistrictIds.Count > 0 && x.DistrictIds.Distinct().Count() <= limits.MaxDistricts)
            .WithMessage("One or more selected districts could not be found.");

        RuleFor(x => x.Questions)
            .Cascade(CascadeMode.Stop)
            .NotNull()
            .Must(questions => questions.Count <= limits.MaxQuestions)
            .WithMessage($"An item can ask at most {limits.MaxQuestions} questions.");

        // The same id twice would be edited twice, silently keeping only the second wording.
        RuleFor(x => x.Questions)
            .Must(questions =>
            {
                var ids = questions.Where(q => q.Id.HasValue).Select(q => q.Id!.Value).ToList();
                return ids.Count == ids.Distinct().Count();
            })
            .When(x => x.Questions is not null)
            .WithMessage("The same question was sent twice.");

        RuleForEach(x => x.Questions).ChildRules(question =>
            question.RuleFor(q => q.Prompt)
                .Must(prompt => !string.IsNullOrWhiteSpace(prompt))
                .WithMessage("Type the question, or remove the row.")
                .MaximumLength(QuestionMaxLength));
    }
}
