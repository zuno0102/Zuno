using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Domain.Exceptions;

namespace Zuno.Marketplace.Application.Admin;

/// <summary>
/// Puts an advert in the customers' top banner until <see cref="PaidUntil"/>, or takes it out (null).
/// A banner is paid for; until the business can pay in the app, a Super Admin records it here.
/// </summary>
public class SetMarketplaceBannerCommand : IRequest<MarketplaceBannerDto>
{
    /// <summary>From the route, not the body.</summary>
    public Guid Id { get; set; }

    public DateTimeOffset? PaidUntil { get; set; }
}

/// <summary>A post and until when its banner runs; null for none.</summary>
public record MarketplaceBannerDto(Guid Id, DateTimeOffset? BannerPaidUntil);

public class SetMarketplaceBannerCommandValidator : AbstractValidator<SetMarketplaceBannerCommand>
{
    /// <summary>The longest a banner can be paid for ahead.</summary>
    public const int MaxDays = 366;

    public SetMarketplaceBannerCommandValidator(TimeProvider clock)
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.PaidUntil)
            .Must(until => until is null || (until > clock.GetUtcNow() && until <= clock.GetUtcNow().AddDays(MaxDays)))
            .WithMessage($"Paid until must be in the future and within {MaxDays} days; leave it empty to end the banner.");
    }
}

public class SetMarketplaceBannerCommandHandler(IMarketplaceDbContext dbContext)
    : IRequestHandler<SetMarketplaceBannerCommand, MarketplaceBannerDto>
{
    public async Task<MarketplaceBannerDto> Handle(SetMarketplaceBannerCommand request, CancellationToken cancellationToken)
    {
        var post = await dbContext.Posts.FirstOrDefaultAsync(p => p.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException("Post", request.Id);

        // The banner is the advert's poster; a product or food offer has no banner photo to show.
        if (request.PaidUntil is not null && post.Kind != MarketplacePostKind.Advertisement)
        {
            throw new DomainException("Only an advert can be put in the banner.");
        }

        post.BannerPaidUntil = request.PaidUntil;
        await dbContext.SaveChangesAsync(cancellationToken);
        return new MarketplaceBannerDto(post.Id, post.BannerPaidUntil);
    }
}
