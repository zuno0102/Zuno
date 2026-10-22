using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.HiringPost.Commands.RemoveUnfilledHiringPosts;

namespace Zuno.Infrastructure.BackgroundJobs;

/// <summary>
/// Runs <see cref="RemoveUnfilledHiringPostsCommand"/> on a timer, outside any request. While the
/// API sleeps nothing runs, which is harmless: the business list already hides these posts, so
/// the job only tidies the table.
/// </summary>
public class UnfilledHiringPostCleanupService(
    IServiceScopeFactory scopeFactory,
    IOptions<HiringPostCleanupSettings> settings,
    ILogger<UnfilledHiringPostCleanupService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(settings.Value.IntervalMinutes));

        do
        {
            await RunOnceAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task RunOnceAsync(CancellationToken stoppingToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var mediator = scope.ServiceProvider.GetRequiredService<IMediator>();

            var removed = await mediator.Send(
                new RemoveUnfilledHiringPostsCommand { BatchSize = settings.Value.BatchSize },
                stoppingToken);

            if (removed > 0)
            {
                logger.LogInformation("Removed {Count} unfilled hiring posts that had ended.", removed);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Shutting down: the next start picks up where this left off.
        }
        catch (Exception ex)
        {
            // Logged and retried on the next tick; one bad run must not stop the job for good.
            logger.LogError(ex, "Unfilled hiring post cleanup failed.");
        }
    }
}
