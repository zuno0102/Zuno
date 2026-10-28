using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Infrastructure.BackgroundJobs;

/// <summary>
/// Loads the platform settings and the apps' labels and colours at start-up and re-reads them on a
/// timer, so a row changed in any of those tables reaches every instance without a restart.
/// </summary>
public class PlatformSettingsRefreshService(
    IPlatformSettings settings,
    IUiConfigStore uiConfig,
    IOptions<PlatformSettingsOptions> options,
    ILogger<PlatformSettingsRefreshService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.Value.RefreshSeconds));

        do
        {
            // Each on its own: a failure in one must not keep the other stale.
            await RefreshAsync("platform settings", settings.RefreshAsync, stoppingToken);
            await RefreshAsync("UI labels and colours", uiConfig.RefreshAsync, stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task RefreshAsync(string what, Func<CancellationToken, Task> refresh, CancellationToken stoppingToken)
    {
        try
        {
            await refresh(stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Shutting down.
        }
        catch (Exception ex)
        {
            // What is already in memory stays in force; the next tick tries again.
            logger.LogError(ex, "Refreshing {What} failed; keeping the values already loaded.", what);
        }
    }
}
