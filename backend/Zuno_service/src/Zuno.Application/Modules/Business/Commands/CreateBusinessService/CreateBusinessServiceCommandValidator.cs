using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessService;

public class CreateBusinessServiceCommandValidator : AbstractValidator<CreateBusinessServiceCommand>
{
    public CreateBusinessServiceCommandValidator(IApplicationDbContext dbContext)
    {
        RuleFor(x => x.ServiceCategoryId)
            .MustAsync((id, cancellationToken) =>
                dbContext.ServiceCategories.AnyAsync(c => c.Id == id && c.IsActive, cancellationToken))
            .WithMessage("ServiceCategoryId must reference an active service category.");

        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.ItemName).MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(1000);

        RuleFor(x => x.PriceType)
            .NotEmpty()
            .Must(value => Enum.TryParse<PriceType>(value, ignoreCase: true, out _))
            .WithMessage($"PriceType must be one of: {string.Join(", ", Enum.GetNames<PriceType>())}.");

        RuleFor(x => x.Price).GreaterThan(0);

        RuleFor(x => x.EstimatedDurationMinutes)
            .GreaterThan((short)0)
            .When(x => x.EstimatedDurationMinutes.HasValue);

        // Zero is a real answer, not a missing one: it means "depends on the event — agreed with
        // the customer when the order comes in". A wedding package can be a fixed ₹50,000 and
        // still need a crew that only the guest count decides.
        RuleFor(x => x.RequiredWorkerCount)
            .GreaterThanOrEqualTo(0)
            .WithMessage(
                "Workers required cannot be negative. Use 0 if the crew is agreed with the "
                + "customer for each order.");

        // Priced by the head, the crew size IS what gets negotiated, so a fixed number here would
        // be contradicted by the first order that agrees a different one.
        RuleFor(x => x.RequiredWorkerCount)
            .Equal(0)
            .When(x => ServicePricing.IsPerPerson(x.PriceType))
            .WithMessage(
                "A per-person service has no fixed crew size — leave it at 0 and agree the number "
                + "with the customer when the order comes in.");

        RuleFor(x => x.DistrictIds)
            .NotEmpty()
            .WithMessage("Select at least one district where this service is offered.");

        RuleFor(x => x.DistrictIds)
            .MustAsync(async (ids, cancellationToken) =>
            {
                var matchCount = await dbContext.Districts.CountAsync(d => ids.Contains(d.Id), cancellationToken);
                return matchCount == ids.Count;
            })
            .When(x => x.DistrictIds.Count > 0)
            .WithMessage("One or more selected districts could not be found.");
    }
}
