using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Common.Settings;
using Zuno.Infrastructure.Persistence;
using Zuno.Infrastructure.Persistence.Interceptors;
using Zuno.Infrastructure.Repositories;
using Zuno.Infrastructure.Resilience;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure;

public static class DependencyInjection
{
    /// <param name="isDevelopment">
    /// Gates the settings that must never be switched on in a deployed environment — currently
    /// simulated payouts, which report wages as sent without moving money.
    /// </param>
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        bool isDevelopment)
    {
        services.AddHttpContextAccessor();

        services.AddSingleton<IDateTimeProvider, DateTimeProvider>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();

        services.AddScoped<AuditableEntitySaveChangesInterceptor>();

        // The connection string is read when the context is first built, not here. Reading it at
        // registration time baked whichever value was present at that instant into the options,
        // and a test host that supplies its own configuration sources later — as
        // WebApplicationFactory does — had no way to be heard. The integration suite therefore ran
        // against the developer's own database while believing it had a throwaway one.
        services.AddDbContext<ZunoDbContext>((serviceProvider, options) =>
        {
            var connectionString = serviceProvider.GetRequiredService<IConfiguration>()
                    .GetConnectionString("ZunoDatabase")
                ?? throw new InvalidOperationException("Connection string 'ZunoDatabase' was not found.");

            options.UseNpgsql(connectionString)
                .UseSnakeCaseNamingConvention();
        });

        services.AddScoped<IApplicationDbContext>(sp => sp.GetRequiredService<ZunoDbContext>());

        services.AddOptions<JwtSettings>()
            .Bind(configuration.GetSection(JwtSettings.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<FileStorageSettings>()
            .Bind(configuration.GetSection(FileStorageSettings.SectionName));

        services.AddOptions<VerificationSettings>()
            .Bind(configuration.GetSection(VerificationSettings.SectionName));

        // Razorpay moves the money. Its credentials are validated on start-up, so a deployment
        // missing them fails at boot with a clear message rather than at the moment someone
        // tries to pay their crew.
        services.AddOptions<RazorpaySettings>()
            .Bind(configuration.GetSection(RazorpaySettings.SectionName))
            .ValidateDataAnnotations()
            // Simulated payouts outside Development would mean an app reporting wages as sent
            // while no money moved — the one failure a payment system must never have. Refused
            // at boot rather than discovered by an unpaid worker.
            .Validate(
                settings => !settings.SimulatePayouts || isDevelopment,
                "Razorpay:SimulatePayouts must be false outside Development. Simulated payouts "
                + "report success without moving money.")
            // The same danger from the other end: a run that collects nothing still releases
            // wages, so leaving this on in production would pay a crew the business never paid for.
            .Validate(
                settings => !settings.SimulateCollection || isDevelopment,
                "Razorpay:SimulateCollection must be false outside Development. It skips taking "
                + "the business's money while still paying the crew.")
            .ValidateOnStart();

        services.AddHttpClient<IPayoutProvider, RazorpayPayoutProvider>((sp, client) =>
            {
                var razorpay = sp.GetRequiredService<IOptions<RazorpaySettings>>().Value;
                client.BaseAddress = new Uri(razorpay.BaseUrl);
                client.DefaultRequestHeaders.Authorization =
                    RazorpayPayoutProvider.BuildAuthHeader(razorpay);
                client.Timeout = TimeSpan.FromSeconds(30);
            })
            // A payment API is exactly where a blind retry is dangerous, so only the idempotent
            // calls are protected — every payout carries an idempotency key, which is what makes
            // retrying one safe.
            .AddPolicyHandler(PollyPolicies.GetRetryPolicy())
            .AddPolicyHandler(PollyPolicies.GetCircuitBreakerPolicy());

        services.AddScoped<IBusinessReputationService, BusinessReputationService>();
        services.AddScoped<IBusinessTrustService, BusinessTrustService>();
        services.AddScoped<IBookingWageService, BookingWageService>();
        services.AddScoped<IWorkerEarningsService, WorkerEarningsService>();
        // OpenStreetMap requires a real User-Agent identifying the client, and blocks requests
        // without one. This is also why place search is proxied through us rather than called from
        // the app: one identifiable caller, one cache, and a key can be added here later.
        services.AddMemoryCache();

        // Google when a key is configured (GoogleMaps__ApiKey): it knows the shops, halls and small
        // lanes OpenStreetMap is missing in villages. Otherwise the free OpenStreetMap search, so a
        // deployment without a Google account still works.
        var googleMapsKey = configuration["GoogleMaps:ApiKey"];
        if (!string.IsNullOrWhiteSpace(googleMapsKey))
        {
            services.AddHttpClient(nameof(GooglePlaceSearchService), client => client.Timeout = TimeSpan.FromSeconds(10))
                .AddPolicyHandler(PollyPolicies.GetRetryPolicy());
            services.AddScoped<IPlaceSearchService>(provider => new GooglePlaceSearchService(
                provider.GetRequiredService<IHttpClientFactory>().CreateClient(nameof(GooglePlaceSearchService)),
                provider.GetRequiredService<Microsoft.Extensions.Caching.Memory.IMemoryCache>(),
                googleMapsKey,
                provider.GetRequiredService<Microsoft.Extensions.Logging.ILogger<GooglePlaceSearchService>>()));
        }
        else
        {
            services.AddHttpClient<IPlaceSearchService, NominatimPlaceSearchService>(client =>
                {
                    client.BaseAddress = new Uri("https://nominatim.openstreetmap.org");
                    client.DefaultRequestHeaders.UserAgent.ParseAdd("Zuno/1.0 (hiring app; contact: support@zuno.local)");
                    client.Timeout = TimeSpan.FromSeconds(10);
                })
                .AddPolicyHandler(PollyPolicies.GetRetryPolicy());
        }
        // Routing, on the same free OpenStreetMap footing as the place search. The public demo host
        // is for development only; swapping it for a self-hosted OSRM is a change to this URL alone.
        services.AddHttpClient<IRouteService, OsrmRouteService>(client =>
            {
                client.BaseAddress = new Uri("https://router.project-osrm.org");
                client.DefaultRequestHeaders.UserAgent.ParseAdd("Zuno/1.0 (hiring app; contact: support@zuno.local)");
                client.Timeout = TimeSpan.FromSeconds(12);
            })
            .AddPolicyHandler(PollyPolicies.GetRetryPolicy());



        services.AddScoped<IPasswordHasher, PasswordHasher>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IEmailService, EmailService>();
        services.AddScoped<IFileStorageService, LocalFileStorageService>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IBusinessOwnerProfileRepository, BusinessOwnerProfileRepository>();
        services.AddScoped<IBusinessServiceRepository, BusinessServiceRepository>();
        services.AddScoped<IBusinessWorkerRepository, BusinessWorkerRepository>();
        services.AddScoped<IBookingRepository, BookingRepository>();

        // Scaffolded for Phase 2+ external callers (FCM, SMS/email gateways) — see PollyPolicies.
        services.AddHttpClient("Resilient")
            .AddPolicyHandler(PollyPolicies.GetRetryPolicy())
            .AddPolicyHandler(PollyPolicies.GetCircuitBreakerPolicy());

        return services;
    }
}
