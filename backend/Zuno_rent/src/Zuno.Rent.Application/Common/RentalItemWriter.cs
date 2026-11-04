using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Common;

/// <summary>Copies the business's answers onto an item — shared by add and edit.</summary>
internal static class RentalItemWriter
{
    public static async Task ApplyAsync(
        RentalItem item,
        IRentalItemFields fields,
        IRentDbContext dbContext,
        RentSettings settings,
        CancellationToken cancellationToken)
    {
        // The validator has checked both; loading them here also sets the names the reply shows.
        item.RentalCategory = await dbContext.RentalCategories
            .FirstOrDefaultAsync(c => c.Id == fields.RentalCategoryId && c.IsActive, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalCategory), fields.RentalCategoryId);
        item.RentalCategoryId = item.RentalCategory.Id;

        item.RentalSubCategory = fields.RentalSubCategoryId is { } subCategoryId
            ? await dbContext.RentalSubCategories.FirstOrDefaultAsync(
                    s => s.Id == subCategoryId && s.RentalCategoryId == item.RentalCategoryId && s.IsActive,
                    cancellationToken)
                ?? throw new EntityNotFoundException(nameof(RentalSubCategory), subCategoryId)
            : null;
        item.RentalSubCategoryId = item.RentalSubCategory?.Id;

        item.Name = fields.Name.Trim();
        item.Description = string.IsNullOrWhiteSpace(fields.Description) ? null : fields.Description.Trim();
        item.SetRate(RentalPricing.Parse(fields.PriceType)
            ?? throw new DomainException($"Choose how you charge: {RentalPricing.AllowedList}."), fields.Price);
        // Never below what is out with customers; a new item has nothing out.
        item.SetQuantityOwned(
            fields.QuantityOwned,
            await dbContext.QuantityOutAsync(item.Id, cancellationToken));
        var advance = RentalPricing.ParseAdvance(fields.AdvanceType)
            ?? throw new DomainException("Choose no advance, a fixed advance for the order, or an advance per piece.");
        item.SetAdvance(advance, advance == Domain.Enums.RentalAdvanceType.None ? null : fields.AdvanceAmount);
        item.IsAvailable = fields.IsAvailable;
        // The domain checks the limit again, so no path can save a charge above it.
        item.SetCancelCharge(
            RentalPricing.ParseCancelCharge(fields.CancelChargeType)
                ?? throw new DomainException("Choose how the cancellation charge is worked out: by time left or per rental day."),
            fields.CancelSteps.Select(s => new RentalCancelStep { UnitsBefore = s.UnitsBefore, Percent = s.Percent }),
            fields.CancelPercentPerDay,
            RentalCancelLimits.For(item.RentalCategory, item.RentalSubCategory, settings));

        await SetDistrictsAsync(item, fields.DistrictIds.ToHashSet(), dbContext, cancellationToken);
        SetQuestions(item, fields.Questions, dbContext);
    }

    /// <summary>
    /// Makes the item's questions exactly the list sent, in its order. Kept ones are edited in place
    /// (same id), dropped ones are soft-deleted, so an answer already given never loses its question.
    /// </summary>
    private static void SetQuestions(RentalItem item, List<RentalQuestionInput> incoming, IRentDbContext dbContext)
    {
        var keptIds = incoming.Where(q => q.Id.HasValue).Select(q => q.Id!.Value).ToHashSet();

        foreach (var removed in item.Questions.Where(q => !keptIds.Contains(q.Id)).ToList())
        {
            item.Questions.Remove(removed);
            dbContext.RentalItemQuestions.Remove(removed);
        }

        for (var position = 0; position < incoming.Count; position++)
        {
            var input = incoming[position];

            if (input.Id is { } id)
            {
                // Only this item's own questions can be edited; an id from another item is refused.
                var existing = item.Questions.FirstOrDefault(q => q.Id == id)
                    ?? throw new EntityNotFoundException(nameof(RentalItemQuestion), id);
                existing.Prompt = input.Prompt.Trim();
                existing.IsRequired = input.IsRequired;
                existing.SortOrder = (short)position;
                continue;
            }

            var question = new RentalItemQuestion
            {
                RentalItemId = item.Id,
                RentalItem = item,
                Prompt = input.Prompt.Trim(),
                IsRequired = input.IsRequired,
                SortOrder = (short)position,
            };
            dbContext.RentalItemQuestions.Add(question);
            item.Questions.AddIfMissing(question);
        }
    }

    /// <summary>
    /// Keeps the districts still chosen, removes the rest and adds the new ones. New rows go on the
    /// DbSet, so EF inserts them rather than mistaking their preset key for an update; EF then puts
    /// them in the item's list itself.
    /// </summary>
    private static async Task SetDistrictsAsync(
        RentalItem item, HashSet<Guid> wanted, IRentDbContext dbContext, CancellationToken cancellationToken)
    {
        foreach (var existing in item.Districts.Where(d => !wanted.Contains(d.DistrictId)).ToList())
        {
            item.Districts.Remove(existing);
            dbContext.RentalItemDistricts.Remove(existing);
        }

        var kept = item.Districts.Select(d => d.DistrictId).ToHashSet();
        var added = wanted.Where(id => !kept.Contains(id)).ToList();
        if (added.Count == 0)
        {
            return;
        }

        var districts = await dbContext.Districts
            .Include(d => d.State)
            .Where(d => added.Contains(d.Id))
            .ToListAsync(cancellationToken);

        foreach (var district in districts)
        {
            var row = new RentalItemDistrict { RentalItemId = item.Id, RentalItem = item, DistrictId = district.Id, District = district };
            dbContext.RentalItemDistricts.Add(row);
            item.Districts.AddIfMissing(row);
        }
    }

    /// <summary>
    /// Adds a new child row to its item's list unless EF has already put it there. Adding it to the
    /// DbSet makes EF link it to the tracked item, so adding it again would show it twice.
    /// </summary>
    public static void AddIfMissing<T>(this ICollection<T> list, T row)
    {
        if (!list.Contains(row))
        {
            list.Add(row);
        }
    }
}
