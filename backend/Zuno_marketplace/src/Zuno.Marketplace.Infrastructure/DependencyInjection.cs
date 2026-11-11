using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Infrastructure.Persistence;
using Zuno.Marketplace.Infrastructure.Services;

namespace Zuno.Marketplace.Infrastructure;

public static class DependencyInjection
{
    public const string ConnectionStringName = "MarketplaceDatabase";

    public const string MigrateOnStartupKey = "Database:MigrateOnStartup";

    public static IServiceCollection AddMarketplaceInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddHttpContextAccessor();
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<AuditInterceptor>();

        services.AddOptions<MarketplaceSettings>()
            .Bind(configuration.GetSection(MarketplaceSettings.SectionName))
            .ValidateDataAnnotations()
            .Validate(s => s.DefaultPageSize <= s.MaxPageSize, "Marketplace:DefaultPageSize must not exceed MaxPageSize.")
            .ValidateOnStart();
        services.AddOptions<MarketplaceFileStorageSettings>()
            .Bind(configuration.GetSection(MarketplaceFileStorageSettings.SectionName));
        services.AddOptions<ServiceApiSettings>()
            .Bind(configuration.GetSection(ServiceApiSettings.SectionName));

        // Names and verification come from the Service API, asked with the caller's own login.
        services.AddHttpClient<IServiceDirectory, ServiceDirectory>();

        // Read when the context is first built, not here, so a test host's own connection string is
        // the one used.
        services.AddDbContext<MarketplaceDbContext>((serviceProvider, options) =>
        {
            var config = serviceProvider.GetRequiredService<IConfiguration>();
            var connectionString = config.GetConnectionString(ConnectionStringName)
                ?? throw new InvalidOperationException($"Connection string '{ConnectionStringName}' was not found.");

            // A bounded pool per instance, so one busy instance cannot take every connection the
            // server has. An explicit pool size in the connection string still wins.
            var builder = new NpgsqlConnectionStringBuilder(connectionString);
            if (!connectionString.Contains("Maximum Pool Size", StringComparison.OrdinalIgnoreCase)
                && !connectionString.Contains("MaxPoolSize", StringComparison.OrdinalIgnoreCase))
            {
                builder.MaxPoolSize = config.GetValue("Database:MaxPoolSize", 20);
            }

            // Split queries: a post's photos load as one small query instead of a join whose rows multiply.
            options.UseNpgsql(builder.ConnectionString, npgsql => npgsql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery))
                .UseSnakeCaseNamingConvention()
                .AddInterceptors(serviceProvider.GetRequiredService<AuditInterceptor>());
        });

        services.AddScoped<IMarketplaceDbContext>(sp => sp.GetRequiredService<MarketplaceDbContext>());
        services.AddScoped<IMarketplaceMediaStorage, MarketplaceMediaStorage>();

        return services;
    }

    /// <summary>
    /// Brings the Marketplace database up to date before the API takes traffic. Switched by
    /// <c>Database:MigrateOnStartup</c>. Not caught: a failed migration stops the new instance from
    /// starting, and the previous deploy keeps serving.
    /// </summary>
    public static async Task MigrateMarketplaceDatabaseAsync(this IServiceProvider services, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();

        if (!scope.ServiceProvider.GetRequiredService<IConfiguration>().GetValue<bool>(MigrateOnStartupKey))
        {
            return;
        }

        var dbContext = scope.ServiceProvider.GetRequiredService<MarketplaceDbContext>();
        var pending = (await dbContext.Database.GetPendingMigrationsAsync(cancellationToken)).ToList();
        if (pending.Count == 0)
        {
            return;
        }

        scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("Zuno.Marketplace.Migrations")
            .LogInformation("Applying {Count} Marketplace migration(s): {Migrations}", pending.Count, string.Join(", ", pending));
        await dbContext.Database.MigrateAsync(cancellationToken);
    }
}
