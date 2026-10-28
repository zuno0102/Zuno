using Polly;
using Polly.Extensions.Http;

namespace Zuno.Infrastructure.Resilience;

/// <summary>
/// Scaffolded now with no live caller — Auth makes no outbound HTTP calls. Becomes load-bearing
/// starting with the Notification module (FCM push) and any external SMS/email gateway, so that
/// a slow/failing third-party dependency degrades gracefully instead of blocking the caller.
/// </summary>
public static class PollyPolicies
{
    public static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy() =>
        HttpPolicyExtensions
            .HandleTransientHttpError()
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)));

    public static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy() =>
        HttpPolicyExtensions
            .HandleTransientHttpError()
            .CircuitBreakerAsync(
                handledEventsAllowedBeforeBreaking: 5,
                durationOfBreak: TimeSpan.FromSeconds(30));
}
