using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Zuno.Infrastructure.Persistence;

/// <summary>
/// Brings the database schema up to date before the API takes traffic, so a deploy can never
/// put new code in front of an old schema. Switched by <c>Database:MigrateOnStartup</c>.
/// </summary>
/// <remarks>
/// Deliberately not caught: if a migration fails, the new instance never starts, and Render
/// keeps serving the previous deploy against the schema it was built for. EF Core takes a
/// database lock while migrating, so two instances starting together cannot both apply one.
/// </remarks>
public static class DatabaseMigrator
{
    public const string SettingKey = "Database:MigrateOnStartup";

    public static async Task MigrateAsync(IServiceProvider services, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();

        var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        if (!configuration.GetValue<bool>(SettingKey))
        {
            return;
        }

        var dbContext = scope.ServiceProvider.GetRequiredService<ZunoDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(DatabaseMigrator));

        var pending = (await dbContext.Database.GetPendingMigrationsAsync(cancellationToken)).ToList();
        if (pending.Count == 0)
        {
            return;
        }

        logger.LogInformation("Applying {Count} database migration(s): {Migrations}", pending.Count, string.Join(", ", pending));
        await dbContext.Database.MigrateAsync(cancellationToken);
    }
}
