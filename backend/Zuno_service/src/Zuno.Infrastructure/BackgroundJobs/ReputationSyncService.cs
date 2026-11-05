using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.BackgroundJobs;

/// <summary>
/// Runs <see cref="IBusinessReputationSync"/> on a timer, outside any request: copies each business's Rent
/// figures in and lets every level take the step that time has made due. How often is the
/// <c>reputation.sync-minutes</c> platform setting, read before each wait so a change applies without a restart.
/// </summary>
/// <remarks>
/// A failed run — the database busy, the Rent API down — is logged and tried again next time; it never
/// stops the job or the API. While the API sleeps nothing runs, which only delays the next step.
/// </remarks>
public class ReputationSyncService(
    IServiceScopeFactory scopeFactory,
    IPlatformSettings platformSettings,
    ILogger<ReputationSyncService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await RunOnceAsync(stoppingToken);

            try
            {
                await Task.Delay(
                    TimeSpan.FromMinutes(platformSettings.Current.ReputationSyncMinutes),
                    stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // Shutting down.
                return;
            }
        }
    }

    private async Task RunOnceAsync(CancellationToken stoppingToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var sync = scope.ServiceProvider.GetRequiredService<IBusinessReputationSync>();

            var updated = await sync.RunAsync(stoppingToken);
            logger.LogInformation("Refreshed the standing of {Count} businesses.", updated);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Shutting down: the next start runs a fresh pass.
        }
        catch (Exception ex)
        {
            // Logged and retried on the next tick; one bad run must not stop the job for good.
            logger.LogError(ex, "Refreshing business standings failed.");
        }
    }
}
