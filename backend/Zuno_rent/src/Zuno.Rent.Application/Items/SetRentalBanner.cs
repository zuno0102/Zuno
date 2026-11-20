using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Items;

/// <summary>
/// Puts a rent item in the customers' top banner until <see cref="PaidUntil"/>, or takes it out (null).
/// A banner is paid for; until the business can pay in the app, a Super Admin records it here.
/// </summary>
public class SetRentalBannerCommand : IRequest<RentalBannerDto>
{
    /// <summary>From the route, not the body.</summary>
    public Guid Id { get; set; }

    public DateTimeOffset? PaidUntil { get; set; }
}

/// <summary>An item and until when its banner runs; null for none.</summary>
public record RentalBannerDto(Guid Id, DateTimeOffset? BannerPaidUntil);

public class SetRentalBannerCommandValidator : AbstractValidator<SetRentalBannerCommand>
{
    /// <summary>The longest a banner can be paid for ahead.</summary>
    public const int MaxDays = 366;

    public SetRentalBannerCommandValidator(TimeProvider clock)
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.PaidUntil)
            .Must(until => until is null || (until > clock.GetUtcNow() && until <= clock.GetUtcNow().AddDays(MaxDays)))
            .WithMessage($"Paid until must be in the future and within {MaxDays} days; leave it empty to end the banner.");
    }
}

public class SetRentalBannerCommandHandler(IRentDbContext dbContext) : IRequestHandler<SetRentalBannerCommand, RentalBannerDto>
{
    public async Task<RentalBannerDto> Handle(SetRentalBannerCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.RentalItems.FirstOrDefaultAsync(i => i.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), request.Id);

        item.BannerPaidUntil = request.PaidUntil;
        await dbContext.SaveChangesAsync(cancellationToken);
        return new RentalBannerDto(item.Id, item.BannerPaidUntil);
    }
}
