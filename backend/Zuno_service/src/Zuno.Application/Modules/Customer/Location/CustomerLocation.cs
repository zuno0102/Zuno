using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Customer.Location;

/// <summary>The customer's saved location, so a phone they sign in on starts where they are.</summary>
public record GetMyCustomerLocationQuery : IRequest<CustomerLocationDto>;

/// <summary>
/// Saves where the customer is. A district with <see cref="CustomerLocationSources.Gps"/> (read from
/// the phone) or <see cref="CustomerLocationSources.Manual"/> (picked); no district with
/// <see cref="CustomerLocationSources.Cleared"/> (everywhere, on purpose).
/// </summary>
public record SetMyCustomerLocationCommand(Guid? DistrictId, string Source) : IRequest<CustomerLocationDto>;

/// <summary>Everything is null for a customer who has never set a location.</summary>
public record CustomerLocationDto(
    Guid? DistrictId,
    string? DistrictName,
    Guid? StateId,
    string? StateName,
    string? Source,
    DateTimeOffset? UpdatedAt);

public class SetMyCustomerLocationCommandValidator : AbstractValidator<SetMyCustomerLocationCommand>
{
    public SetMyCustomerLocationCommandValidator()
    {
        RuleFor(x => x.Source)
            .Must(source => CustomerLocationSources.All.Contains(source))
            .WithMessage("Unknown location source.");
        RuleFor(x => x.DistrictId)
            .NotNull().When(x => x.Source != CustomerLocationSources.Cleared)
            .WithMessage("Choose a district.");
        RuleFor(x => x.DistrictId)
            .Null().When(x => x.Source == CustomerLocationSources.Cleared)
            .WithMessage("A cleared location has no district.");
    }
}

public class CustomerLocationHandlers(
    IApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider clock) :
    IRequestHandler<GetMyCustomerLocationQuery, CustomerLocationDto>,
    IRequestHandler<SetMyCustomerLocationCommand, CustomerLocationDto>
{
    public async Task<CustomerLocationDto> Handle(GetMyCustomerLocationQuery request, CancellationToken cancellationToken)
    {
        var profile = await ProfileQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(cp => cp.UserId == UserId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(CustomerProfile), UserId);
        return ToDto(profile);
    }

    public async Task<CustomerLocationDto> Handle(SetMyCustomerLocationCommand request, CancellationToken cancellationToken)
    {
        var profile = await ProfileQuery()
            .FirstOrDefaultAsync(cp => cp.UserId == UserId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(CustomerProfile), UserId);

        District? district = null;
        if (request.DistrictId is { } districtId)
        {
            district = await dbContext.Districts
                .Include(d => d.State)
                .FirstOrDefaultAsync(d => d.Id == districtId, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(District), districtId);
        }

        profile.LocationDistrictId = district?.Id;
        profile.LocationDistrict = district;
        profile.LocationSource = request.Source;
        profile.LocationUpdatedAt = clock.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToDto(profile);
    }

    private Guid UserId => currentUserService.UserId
        ?? throw new UnauthorizedAccessException("User is not authenticated.");

    private IQueryable<CustomerProfile> ProfileQuery() =>
        dbContext.CustomerProfiles.Include(cp => cp.LocationDistrict).ThenInclude(d => d!.State);

    private static CustomerLocationDto ToDto(CustomerProfile profile) => new(
        profile.LocationDistrict?.Id,
        profile.LocationDistrict?.Name,
        profile.LocationDistrict?.StateId,
        profile.LocationDistrict?.State.Name,
        profile.LocationSource,
        profile.LocationUpdatedAt);
}
