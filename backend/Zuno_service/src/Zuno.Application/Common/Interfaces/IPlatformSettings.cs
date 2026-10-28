using Zuno.Application.Common.Settings;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// The business rules in force right now, from the <c>platform_settings</c> table.
/// </summary>
/// <remarks>
/// Held in memory and refreshed in the background, so reading <see cref="Current"/> never touches the
/// database: every request on every instance gets the rules for free. A change to the table reaches
/// all instances within one refresh interval, or at once on the instance that called
/// <see cref="RefreshAsync"/>.
/// </remarks>
public interface IPlatformSettings
{
    PlatformRules Current { get; }

    /// <summary>Reloads the rules from the table now — after an admin edit, or on start-up.</summary>
    Task RefreshAsync(CancellationToken cancellationToken);
}
