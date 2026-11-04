using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Domain.Entities;
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

    /// <summary>
    /// What a customer pays for cancelling, by time left before the start: e.g. 5+ days → 0.5%,
    /// 2+ days → 1%, same day (0) → 2%. Days, or hours for an hourly item. Empty means free.
    /// </summary>
    List<RentalCancelStepInput> CancelSteps { get; }

    /// <summary><c>ByTimeLeft</c> (the steps) or <c>PerRentalDay</c>; empty means by time left.</summary>
    string? CancelChargeType { get; }

    /// <summary>For <c>PerRentalDay</c>: the percent for each day (or hour) rented, e.g. 1.</summary>
    decimal? CancelPercentPerDay { get; }
}

/// <summary>One step of the cancellation charge as the business types it.</summary>
public class RentalCancelStepInput
{
    /// <summary>Days (hours for an hourly item) or more before the start; 0 is the start day itself.</summary>
    public int UnitsBefore { get; set; }

    public decimal Percent { get; set; }
}

/// <summary>
/// How much of an order a business may keep on a cancellation: what the super admin set for the
/// category (or its sub-category), never above the platform's ceiling.
/// </summary>
public static class RentalCancelLimits
{
    public static decimal For(RentalCategory category, RentalSubCategory? subCategory, RentSettings settings) =>
        Math.Min(category.CancelLimitFor(subCategory), settings.CancelPercentCeiling);

    /// <summary>The limit and the name it is told by ("Plastic chairs"); null when the category is not offered.</summary>
    public static async Task<(string Name, decimal Percent)?> ForAsync(
        IRentDbContext dbContext,
        Guid categoryId,
        Guid? subCategoryId,
        RentSettings settings,
        CancellationToken cancellationToken)
    {
        var category = await dbContext.RentalCategories
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == categoryId && c.IsActive, cancellationToken);
        if (category is null)
        {
            return null;
        }

        var subCategory = subCategoryId is { } id
            ? await dbContext.RentalSubCategories
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.Id == id && s.RentalCategoryId == categoryId && s.IsActive, cancellationToken)
            : null;

        var name = subCategory?.MaxCancelPercent is not null ? subCategory.Name : category.Name;
        return (name, For(category, subCategory, settings));
    }

    /// <summary>The furthest a step can start: days, or the same in hours for an hourly item.</summary>
    public static int MaxUnitsBefore(RentalPriceType? priceType, RentSettings settings) =>
        priceType == RentalPriceType.Hourly ? settings.MaxCancelDaysBefore * 24 : settings.MaxCancelDaysBefore;
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

    /// <summary>How the cancellation charge is worked out; empty is by time left, anything unknown is null.</summary>
    public static RentalCancelChargeType? ParseCancelCharge(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? RentalCancelChargeType.ByTimeLeft
            : !int.TryParse(value, out _)
                && Enum.TryParse<RentalCancelChargeType>(value, ignoreCase: true, out var parsed)
                && Enum.IsDefined(parsed)
                ? parsed
                : null;

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

        RuleFor(x => x.CancelSteps)
            .Cascade(CascadeMode.Stop)
            .NotNull()
            .Must(steps => steps.Count <= limits.MaxCancelSteps)
            .WithMessage($"An item can have at most {limits.MaxCancelSteps} cancellation steps.")
            .Must(steps => steps.Select(s => s.UnitsBefore).Distinct().Count() == steps.Count)
            .WithMessage("Each cancellation step needs its own number of days or hours.")
            .Must(steps => steps.Count == 0 || steps.Any(s => s.UnitsBefore == 0))
            .WithMessage("Add a step for cancelling on the start day itself (0).")
            .Must(steps =>
            {
                var ordered = steps.OrderBy(s => s.UnitsBefore).ToList();
                return ordered.Zip(ordered.Skip(1)).All(pair => pair.Second.Percent <= pair.First.Percent);
            })
            .WithMessage("Cancelling earlier cannot cost more than cancelling later.");

        RuleForEach(x => x.CancelSteps).ChildRules(step =>
        {
            step.RuleFor(s => s.UnitsBefore)
                .GreaterThanOrEqualTo(0)
                .WithMessage("A cancellation step starts at 0 (same day) or later.");
            step.RuleFor(s => s.Percent)
                .GreaterThanOrEqualTo(0)
                .WithMessage("A cancellation charge cannot be below 0%.")
                .PrecisionScale(5, 2, ignoreTrailingZeros: true)
                .WithMessage("Use at most 2 decimals for a cancellation charge, e.g. 1.5%.");
        });

        RuleForEach(x => x.CancelSteps)
            .Must((fields, step) => step.UnitsBefore <= RentalCancelLimits.MaxUnitsBefore(RentalPricing.Parse(fields.PriceType), limits))
            .When(x => x.CancelSteps is not null)
            .WithMessage(fields => RentalPricing.Parse(fields.PriceType) == RentalPriceType.Hourly
                ? $"A cancellation step can start at most {limits.MaxCancelDaysBefore * 24} hours before."
                : $"A cancellation step can start at most {limits.MaxCancelDaysBefore} days before.");

        RuleFor(x => x.CancelChargeType)
            .Must(value => RentalPricing.ParseCancelCharge(value).HasValue)
            .WithMessage("Choose how the cancellation charge is worked out: by time left or per rental day.")
            .DependentRules(() => RuleFor(x => x.CancelChargeType)
                .MustAsync((value, cancellationToken) =>
                {
                    var code = RentalPricing.ParseCancelCharge(value)!.Value;
                    return dbContext.RentalCancelChargeTypes.AnyAsync(c => c.Code == code && c.IsActive, cancellationToken);
                })
                .WithMessage("That way of working out the charge is not offered any more. Choose another."));

        RuleFor(x => x.CancelPercentPerDay)
            .NotNull()
            .WithMessage("Enter the charge for each rental day, e.g. 1%.")
            .GreaterThan(0)
            .WithMessage("The charge for each rental day must be more than 0%.")
            .PrecisionScale(5, 2, ignoreTrailingZeros: true)
            .WithMessage("Use at most 2 decimals for a cancellation charge, e.g. 1.5%.")
            .When(x => RentalPricing.ParseCancelCharge(x.CancelChargeType) == RentalCancelChargeType.PerRentalDay);

        RuleFor(x => x.CancelSteps)
            .Must(steps => steps.Count == 0)
            .When(x => x.CancelSteps is not null
                && RentalPricing.ParseCancelCharge(x.CancelChargeType) == RentalCancelChargeType.PerRentalDay)
            .WithMessage("Use either steps by time left or a charge per rental day, not both.");

        // A per-day charge is checked against the same limit: plastic chairs allow 2% a day at most.
        RuleFor(x => x.CancelPercentPerDay)
            .CustomAsync(async (perDay, context, cancellationToken) =>
            {
                var fields = context.InstanceToValidate;
                var limit = await RentalCancelLimits.ForAsync(
                    dbContext, fields.RentalCategoryId, fields.RentalSubCategoryId, limits, cancellationToken);
                if (limit is { } found && perDay > found.Percent)
                {
                    context.AddFailure(
                        $"For {found.Name}, the cancellation charge can be at most {found.Percent:0.##}%.");
                }
            })
            .When(x => x.CancelPercentPerDay is > 0
                && RentalPricing.ParseCancelCharge(x.CancelChargeType) == RentalCancelChargeType.PerRentalDay);

        // The super admin's limit for the kind of item: plastic chairs allow 2%, so 5% is refused.
        RuleFor(x => x.CancelSteps)
            .CustomAsync(async (steps, context, cancellationToken) =>
            {
                var fields = context.InstanceToValidate;
                var limit = await RentalCancelLimits.ForAsync(
                    dbContext, fields.RentalCategoryId, fields.RentalSubCategoryId, limits, cancellationToken);
                if (limit is { } found && steps.Max(s => s.Percent) > found.Percent)
                {
                    context.AddFailure(
                        $"For {found.Name}, the cancellation charge can be at most {found.Percent:0.##}%.");
                }
            })
            .When(x => x.CancelSteps is { Count: > 0 });
    }
}
