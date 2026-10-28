using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Application.UnitTests;

/// <summary>
/// Platform settings for tests: the shipped defaults, or whatever a test sets — so a test can prove a
/// rule follows the table rather than a literal.
/// </summary>
public sealed class TestPlatformSettings(PlatformRules? rules = null) : IPlatformSettings
{
    public PlatformRules Current { get; set; } = rules ?? PlatformRules.Defaults;

    public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
