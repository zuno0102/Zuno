using FluentValidation;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Admin.Commands.SetServiceBanner;

public class SetServiceBannerCommandValidator : AbstractValidator<SetServiceBannerCommand>
{
    /// <summary>The longest a banner can be paid for ahead.</summary>
    public const int MaxDays = 366;

    public SetServiceBannerCommandValidator(IDateTimeProvider clock)
    {
        RuleFor(x => x.ServiceId).NotEmpty();
        RuleFor(x => x.PaidUntil)
            .Must(until => until is null || (until > clock.UtcNow && until <= clock.UtcNow.AddDays(MaxDays)))
            .WithMessage($"Paid until must be in the future and within {MaxDays} days; leave it empty to end the banner.");
    }
}
