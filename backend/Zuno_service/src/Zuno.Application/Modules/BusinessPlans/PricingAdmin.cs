using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.BusinessPlans;

/// <summary>A plan row as the Super Admin edits it.</summary>
public class AdminPlanDto
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string Period { get; set; } = string.Empty;

    public bool IncludesService { get; set; }

    public bool IncludesRent { get; set; }

    public bool IncludesMarketplace { get; set; }

    public int? MaxLiveListings { get; set; }

    public decimal Price { get; set; }

    public int? DurationDays { get; set; }

    public bool IsDefault { get; set; }

    public bool IsActive { get; set; }

    public short SortOrder { get; set; }
}

/// <summary>A full-time hiring post option as the Super Admin edits it.</summary>
public class AdminHiringPlanDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public int ListingDays { get; set; }

    public bool IsActive { get; set; }

    public short SortOrder { get; set; }
}

public class PricingDto
{
    public List<AdminPlanDto> Plans { get; set; } = [];

    public List<AdminHiringPlanDto> HiringPlans { get; set; } = [];
}

public record GetPricingQuery : IRequest<PricingDto>;

/// <summary>
/// A plan's name, price, length, on-sale switch and order. Its areas and code stay as they are; the
/// Basic plan's limit is changed here too. A new price applies to purchases started after it.
/// </summary>
public record UpdatePlanCommand(
    Guid Id, string Name, decimal Price, int? DurationDays, int? MaxLiveListings, bool IsActive, short SortOrder) : IRequest<AdminPlanDto>;

/// <summary>Adds (no <see cref="Id"/>) or changes a full-time hiring post option.</summary>
public record SaveHiringPlanCommand(
    Guid? Id, string Name, decimal Amount, int ListingDays, bool IsActive, short SortOrder) : IRequest<AdminHiringPlanDto>;

public class UpdatePlanCommandValidator : AbstractValidator<UpdatePlanCommand>
{
    public UpdatePlanCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Price).InclusiveBetween(0m, 1_000_000m);
        RuleFor(x => x.DurationDays).InclusiveBetween(1, 3660).When(x => x.DurationDays is not null);
        RuleFor(x => x.MaxLiveListings).InclusiveBetween(0, 10_000).When(x => x.MaxLiveListings is not null);
    }
}

public class SaveHiringPlanCommandValidator : AbstractValidator<SaveHiringPlanCommand>
{
    public SaveHiringPlanCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Amount).InclusiveBetween(0m, 1_000_000m);
        RuleFor(x => x.ListingDays).InclusiveBetween(1, 3660);
    }
}

public class PricingAdminHandlers(IApplicationDbContext dbContext) :
    IRequestHandler<GetPricingQuery, PricingDto>,
    IRequestHandler<UpdatePlanCommand, AdminPlanDto>,
    IRequestHandler<SaveHiringPlanCommand, AdminHiringPlanDto>
{
    public async Task<PricingDto> Handle(GetPricingQuery request, CancellationToken cancellationToken) => new()
    {
        Plans = (await dbContext.SubscriptionPlans.AsNoTracking().OrderBy(p => p.SortOrder).ToListAsync(cancellationToken))
            .Select(ToDto).ToList(),
        HiringPlans = (await dbContext.VacancyFeePlans.AsNoTracking().OrderBy(p => p.SortOrder).ToListAsync(cancellationToken))
            .Select(ToDto).ToList(),
    };

    public async Task<AdminPlanDto> Handle(UpdatePlanCommand request, CancellationToken cancellationToken)
    {
        var plan = await dbContext.SubscriptionPlans.FirstOrDefaultAsync(p => p.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(SubscriptionPlan), request.Id);
        if (plan.IsDefault)
        {
            // Basic is free, never ends and is always on: only its name and limit change.
            if (request.Price != 0m || request.DurationDays is not null || !request.IsActive)
            {
                throw new DomainException("The Basic plan stays free, never ends and stays on. Change its name or limit only.");
            }
        }
        else if (request.DurationDays is null)
        {
            throw new DomainException("A paid plan needs a number of days.");
        }

        plan.Name = request.Name.Trim();
        plan.Price = request.Price;
        plan.DurationDays = request.DurationDays;
        plan.MaxLiveListings = plan.IsDefault ? request.MaxLiveListings : plan.MaxLiveListings;
        plan.IsActive = request.IsActive;
        plan.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToDto(plan);
    }

    public async Task<AdminHiringPlanDto> Handle(SaveHiringPlanCommand request, CancellationToken cancellationToken)
    {
        VacancyFeePlan plan;
        if (request.Id is { } id)
        {
            plan = await dbContext.VacancyFeePlans.FirstOrDefaultAsync(p => p.Id == id, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(VacancyFeePlan), id);
        }
        else
        {
            plan = new VacancyFeePlan();
            dbContext.VacancyFeePlans.Add(plan);
        }

        plan.Name = request.Name.Trim();
        plan.Amount = request.Amount;
        plan.ListingDays = request.ListingDays;
        plan.IsActive = request.IsActive;
        plan.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToDto(plan);
    }

    private static AdminPlanDto ToDto(SubscriptionPlan p) => new()
    {
        Id = p.Id,
        Code = p.Code,
        Name = p.Name,
        Period = p.Period.ToString(),
        IncludesService = p.IncludesService,
        IncludesRent = p.IncludesRent,
        IncludesMarketplace = p.IncludesMarketplace,
        MaxLiveListings = p.MaxLiveListings,
        Price = p.Price,
        DurationDays = p.DurationDays,
        IsDefault = p.IsDefault,
        IsActive = p.IsActive,
        SortOrder = p.SortOrder,
    };

    private static AdminHiringPlanDto ToDto(VacancyFeePlan p) => new()
    {
        Id = p.Id,
        Name = p.Name,
        Amount = p.Amount,
        ListingDays = p.ListingDays,
        IsActive = p.IsActive,
        SortOrder = p.SortOrder,
    };
}
