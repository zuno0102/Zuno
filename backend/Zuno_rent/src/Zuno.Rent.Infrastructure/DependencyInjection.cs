using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Npgsql;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Infrastructure.Persistence;
using Zuno.Rent.Infrastructure.Services;

namespace Zuno.Rent.Infrastructure;

public static class DependencyInjection
{
    public const string ConnectionStringName = "RentDatabase";

    public const string MigrateOnStartupKey = "Database:MigrateOnStartup";

    public static IServiceCollection AddRentInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddHttpContextAccessor();
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<AuditInterceptor>();

        services.AddOptions<RentSettings>()
            .Bind(configuration.GetSection(RentSettings.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();
        services.AddOptions<RentFileStorageSettings>()
            .Bind(configuration.GetSection(RentFileStorageSettings.SectionName));
        services.AddOptions<ServiceApiSettings>()
            .Bind(configuration.GetSection(ServiceApiSettings.SectionName));

        // Names come from the Service API, asked with the caller's own login.
        services.AddHttpClient<IServiceDirectory, ServiceDirectory>();

        // Online payments. Simulated collection takes no money, so it is refused outside Development.
        services.AddOptions<RentPaymentSettings>()
            .Bind(configuration.GetSection(RentPaymentSettings.SectionName))
            .Validate<IHostEnvironment>(
                (settings, environment) => !settings.SimulateCollection || environment.IsDevelopment(),
                "RentPayments:SimulateCollection must be false outside Development: it marks payments as made without taking money.")
            .ValidateOnStart();

        // One merchant account for the whole platform: without Rent keys of its own, Rent takes
        // payments with the Service API's Razorpay keys (same secrets store, same host settings).
        services.PostConfigure<RentPaymentSettings>(settings =>
        {
            if (string.IsNullOrWhiteSpace(settings.KeyId) && string.IsNullOrWhiteSpace(settings.KeySecret))
            {
                settings.KeyId = configuration["Razorpay:KeyId"] ?? string.Empty;
                settings.KeySecret = configuration["Razorpay:KeySecret"] ?? string.Empty;
            }
        });
        services.AddHttpClient<IRentPaymentGateway, RazorpayRentGateway>((sp, client) =>
        {
            client.BaseAddress = new Uri(sp.GetRequiredService<IOptions<RentPaymentSettings>>().Value.BaseUrl);
            client.Timeout = TimeSpan.FromSeconds(15);
        });

        // Lets go of app bookings whose advance was not paid in time.
        services.AddHostedService<AdvanceLapseService>();

        // Read when the context is first built, not here, so a test host's own connection string is
        // the one used.
        services.AddDbContext<RentDbContext>((serviceProvider, options) =>
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

            // Split queries: an item's photos and districts load as one small query each instead of
            // one join whose rows multiply.
            options.UseNpgsql(builder.ConnectionString, npgsql => npgsql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery))
                .UseSnakeCaseNamingConvention()
                .AddInterceptors(serviceProvider.GetRequiredService<AuditInterceptor>());
        });

        services.AddScoped<IRentDbContext>(sp => sp.GetRequiredService<RentDbContext>());
        services.AddScoped<IRentMediaStorage, RentMediaStorage>();

        return services;
    }

    /// <summary>
    /// Brings the Rent database up to date before the API takes traffic. Switched by
    /// <c>Database:MigrateOnStartup</c>. Not caught: a failed migration stops the new instance from
    /// starting, and the previous deploy keeps serving.
    /// </summary>
    public static async Task MigrateRentDatabaseAsync(this IServiceProvider services, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();

        if (!scope.ServiceProvider.GetRequiredService<IConfiguration>().GetValue<bool>(MigrateOnStartupKey))
        {
            return;
        }

        var dbContext = scope.ServiceProvider.GetRequiredService<RentDbContext>();
        var pending = (await dbContext.Database.GetPendingMigrationsAsync(cancellationToken)).ToList();
        if (pending.Count == 0)
        {
            return;
        }

        scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("Zuno.Rent.Migrations")
            .LogInformation("Applying {Count} Rent migration(s): {Migrations}", pending.Count, string.Join(", ", pending));
        await dbContext.Database.MigrateAsync(cancellationToken);
    }
}
