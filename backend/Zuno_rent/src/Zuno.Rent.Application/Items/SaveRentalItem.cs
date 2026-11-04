using FluentValidation;
using MediatR;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Application.Items;

/// <summary>Lists a new item the business rents out, e.g. 200 plastic chairs at ₹12 a day.</summary>
public class CreateRentalItemCommand : IRequest<RentalItemDto>, IRentalItemFields
{
    public Guid RentalCategoryId { get; set; }

    public Guid? RentalSubCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int QuantityOwned { get; set; } = 1;

    public string? AdvanceType { get; set; }

    public decimal? AdvanceAmount { get; set; }

    public bool IsAvailable { get; set; } = true;

    public List<Guid> DistrictIds { get; set; } = [];

    public List<RentalQuestionInput> Questions { get; set; } = [];

    public List<RentalCancelStepInput> CancelSteps { get; set; } = [];

    public string? CancelChargeType { get; set; }

    public decimal? CancelPercentPerDay { get; set; }
}

/// <summary>Edits a rent item, including switching it off while it cannot be rented.</summary>
public class UpdateRentalItemCommand : IRequest<RentalItemDto>, IRentalItemFields
{
    /// <summary>From the route, not the body.</summary>
    public Guid Id { get; set; }

    public Guid RentalCategoryId { get; set; }

    public Guid? RentalSubCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int QuantityOwned { get; set; } = 1;

    public string? AdvanceType { get; set; }

    public decimal? AdvanceAmount { get; set; }

    public bool IsAvailable { get; set; } = true;

    public List<Guid> DistrictIds { get; set; } = [];

    public List<RentalQuestionInput> Questions { get; set; } = [];

    public List<RentalCancelStepInput> CancelSteps { get; set; } = [];

    public string? CancelChargeType { get; set; }

    public decimal? CancelPercentPerDay { get; set; }
}

public class CreateRentalItemCommandValidator : AbstractValidator<CreateRentalItemCommand>
{
    public CreateRentalItemCommandValidator(IRentDbContext dbContext, IOptions<RentSettings> settings)
    {
        Include(new RentalItemFieldsValidator<CreateRentalItemCommand>(dbContext, settings));
    }
}

public class UpdateRentalItemCommandValidator : AbstractValidator<UpdateRentalItemCommand>
{
    public UpdateRentalItemCommandValidator(IRentDbContext dbContext, IOptions<RentSettings> settings)
    {
        RuleFor(x => x.Id).NotEmpty();
        Include(new RentalItemFieldsValidator<UpdateRentalItemCommand>(dbContext, settings));
    }
}

public class SaveRentalItemHandlers(ICurrentUser currentUser, IRentDbContext dbContext, IOptions<RentSettings> settings) :
    IRequestHandler<CreateRentalItemCommand, RentalItemDto>,
    IRequestHandler<UpdateRentalItemCommand, RentalItemDto>
{
    public async Task<RentalItemDto> Handle(CreateRentalItemCommand request, CancellationToken cancellationToken)
    {
        // The owner is whoever is signed in — never an id the app sends.
        var item = new RentalItem { OwnerUserId = currentUser.OwnerId() };
        dbContext.RentalItems.Add(item);

        await RentalItemWriter.ApplyAsync(item, request, dbContext, settings.Value, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return item.ToDto();
    }

    public async Task<RentalItemDto> Handle(UpdateRentalItemCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.Id, currentUser.OwnerId(), cancellationToken);

        await RentalItemWriter.ApplyAsync(item, request, dbContext, settings.Value, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return item.ToDto();
    }
}
