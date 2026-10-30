using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Items;

/// <summary>
/// Sets how many of an item the business has, and whether it can be rented now — the Stock page's
/// quick change, without resending the whole item.
/// </summary>
public class UpdateRentalStockCommand : IRequest<RentalItemDto>
{
    /// <summary>From the route, not the body.</summary>
    public Guid Id { get; set; }

    public int QuantityOwned { get; set; }

    public bool IsAvailable { get; set; }
}

public class UpdateRentalStockCommandValidator : AbstractValidator<UpdateRentalStockCommand>
{
    public UpdateRentalStockCommandValidator(IOptions<RentSettings> settings)
    {
        var limits = settings.Value;

        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.QuantityOwned)
            .GreaterThanOrEqualTo(1)
            .WithMessage("You need at least one of this item to rent it out.")
            .LessThanOrEqualTo(limits.MaxQuantityOwned)
            .WithMessage($"Quantity can be at most {limits.MaxQuantityOwned}.");
    }
}

public class UpdateRentalStockCommandHandler(ICurrentUser currentUser, IRentDbContext dbContext)
    : IRequestHandler<UpdateRentalStockCommand, RentalItemDto>
{
    public async Task<RentalItemDto> Handle(UpdateRentalStockCommand request, CancellationToken cancellationToken)
    {
        // Refused before anything changes unless the item is the caller's.
        var item = await dbContext.OwnedItemAsync(request.Id, currentUser.OwnerId(), cancellationToken);

        // Only these two: the rate, category and questions stay exactly as saved.
        item.SetQuantityOwned(
            request.QuantityOwned,
            await dbContext.QuantityOutAsync(item.Id, cancellationToken));
        item.IsAvailable = request.IsAvailable;

        await dbContext.SaveChangesAsync(cancellationToken);

        return item.ToDto();
    }
}
