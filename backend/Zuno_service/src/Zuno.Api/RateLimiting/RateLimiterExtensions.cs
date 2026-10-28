using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Zuno.Api.Common;

namespace Zuno.Api.RateLimiting;

public static class RateLimiterExtensions
{
    public const string AuthPolicy = "AuthPolicy";

    /// <summary>
    /// Guards the place-search endpoint, which makes an outbound call on whatever the user typed.
    /// Without a limit it is an open proxy onto OpenStreetMap, whose terms we would be breaking on
    /// somebody else's behalf.
    /// </summary>
    public const string PlaceSearchPolicy = "PlaceSearchPolicy";

    /// <summary>
    /// Guards endpoints that take personal documents. Each request writes files to disk, so the
    /// limit is far below the global one.
    /// </summary>
    public const string DocumentUploadPolicy = "DocumentUploadPolicy";

    // The real limits, and the defaults wherever configuration says nothing.
    private const int DefaultGlobalPermits = 100;
    private const int DefaultAuthPermits = 5;
    private const int DefaultPlaceSearchPermits = 15;
    private const int DefaultDocumentUploadPermits = 10;
    private const int DefaultWindowMinutes = 1;

    /// <summary>
    /// Adds the request limits, reading any overrides from the <c>RateLimiting</c> configuration
    /// section.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Configurable rather than hardcoded, for one concrete reason: the integration tests drive the
    /// API in-process, so every request they make arrives from the same address and shares one
    /// partition key. Sixteen security tests registering accounts tripped the five-a-minute auth
    /// limit on each other, and seventeen of them failed against an application that was behaving
    /// exactly as designed — the worst kind of failing test, because the obvious reading is that
    /// the app is broken.
    /// </para>
    /// <para>
    /// There is deliberately no switch to turn limiting off. The tests raise the numbers; they
    /// cannot remove the limiter, so the middleware under test is the same one that runs in
    /// production.
    /// </para>
    /// <para>
    /// The values are resolved per partition through <see cref="IOptions{T}"/>, not read here.
    /// Reading them at registration time captured whatever configuration existed at that instant,
    /// which is before a test host gets to add its own sources, so the overrides above were silently
    /// ignored and the suite throttled itself anyway.
    /// </para>
    /// </remarks>
    public static IServiceCollection AddZunoRateLimiting(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<RateLimitingOptions>(
            configuration.GetSection(RateLimitingOptions.SectionName));

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.OnRejected = async (context, cancellationToken) =>
            {
                var response = ApiResponse.Fail(
                    "Too many requests. Please try again later.",
                    context.HttpContext.TraceIdentifier);

                context.HttpContext.Response.ContentType = "application/json";
                await context.HttpContext.Response.WriteAsJsonAsync(response, cancellationToken);
            };

            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: GetPartitionKey(context),
                    factory: _ => Window(context, o => o.Global, DefaultGlobalPermits)));

            options.AddPolicy(AuthPolicy, context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: GetPartitionKey(context),
                    factory: _ => Window(context, o => o.Auth, DefaultAuthPermits)));

            // Generous for a person tapping Search, nowhere near enough to abuse the upstream
            // provider with.
            options.AddPolicy(PlaceSearchPolicy, context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: GetPartitionKey(context),
                    factory: _ => Window(context, o => o.PlaceSearch, DefaultPlaceSearchPermits)));

            options.AddPolicy(DocumentUploadPolicy, context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: GetPartitionKey(context),
                    factory: _ => Window(context, o => o.DocumentUpload, DefaultDocumentUploadPermits)));
        });

        return services;
    }

    /// <summary>
    /// The window for one partition, with the configured permit count or the real one behind it.
    /// </summary>
    /// <remarks>
    /// Called once per partition key — the first request from an address — rather than per request,
    /// so resolving options here costs nothing measurable.
    /// </remarks>
    private static FixedWindowRateLimiterOptions Window(
        HttpContext context,
        Func<RateLimitingOptions, RateLimitingOptions.PolicyLimit> policy,
        int fallbackPermits)
    {
        var configured = context.RequestServices
            .GetRequiredService<IOptions<RateLimitingOptions>>().Value;

        var permits = policy(configured).PermitLimit;
        var minutes = configured.WindowMinutes;

        return new FixedWindowRateLimiterOptions
        {
            PermitLimit = permits > 0 ? permits : fallbackPermits,
            Window = TimeSpan.FromMinutes(minutes > 0 ? minutes : DefaultWindowMinutes),
            QueueLimit = 0,
        };
    }

    private static string GetPartitionKey(HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}
