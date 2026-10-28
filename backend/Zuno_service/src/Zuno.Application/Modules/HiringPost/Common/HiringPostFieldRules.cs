using FluentValidation;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Common;

namespace Zuno.Application.Modules.HiringPost.Common;

/// <summary>
/// The checks every hiring-post form shares — create, edit, and a one-off date invite — written once.
/// </summary>
/// <remarks>
/// Each reads the limits from the platform settings when it runs rather than when the validator is
/// built, so a limit changed by the app owner applies to the very next request.
/// </remarks>
public static class HiringPostFieldRules
{
    /// <summary>A job length inside the configured range. Omitted means "use the default".</summary>
    public static IRuleBuilderOptions<T, int?> ValidDuration<T>(
        this IRuleBuilder<T, int?> rule, IPlatformSettings settings) =>
        rule
            .Must(minutes => minutes is null
                || (minutes >= settings.Current.HiringPostMinDurationMinutes
                    && minutes <= settings.Current.HiringPostMaxDurationMinutes))
            .WithMessage(_ =>
                $"Duration must be between {settings.Current.HiringPostMinDurationMinutes} minutes "
                + $"and {settings.Current.HiringPostMaxDurationMinutes / 60} hours.");

    /// <summary>At least one worker, and no more than the configured most a post may ask for.</summary>
    public static IRuleBuilderOptions<T, int> ValidWorkersNeeded<T>(
        this IRuleBuilder<T, int> rule, IPlatformSettings settings) =>
        rule
            .Must(count => count >= 1 && count <= settings.Current.HiringPostMaxWorkers)
            .WithMessage(_ => $"Workers needed must be between 1 and {settings.Current.HiringPostMaxWorkers}.");

    /// <summary>A positive wage that fits the money column.</summary>
    public static IRuleBuilderOptions<T, decimal> ValidWage<T>(this IRuleBuilder<T, decimal> rule) =>
        rule
            .GreaterThan(0).WithMessage("Salary must be greater than 0.")
            .LessThanOrEqualTo(MoneyLimits.MaxAmount);
}
