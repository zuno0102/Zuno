using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.BusinessPlans;

namespace Zuno.Infrastructure.BackgroundJobs;

/// <summary>
/// Every hour: ends the paid plans whose time is up and pauses the listings only they allowed. While
/// the API sleeps nothing runs; the first run after waking catches up.
/// </summary>
public class PlanExpiryService(IServiceScopeFactory scopeFactory, ILogger<PlanExpiryService> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);
        do
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var reconciler = scope.ServiceProvider.GetRequiredService<PlanReconciler>();
                var clock = scope.ServiceProvider.GetRequiredService<IDateTimeProvider>();
                var ended = await reconciler.EndDuePlansAsync(clock.UtcNow, stoppingToken);
                if (ended > 0)
                {
                    logger.LogInformation("Ended {Count} paid plans and paused what they alone allowed.", ended);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // Shutting down; the next start catches up.
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Ending paid plans failed; retried next hour.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
