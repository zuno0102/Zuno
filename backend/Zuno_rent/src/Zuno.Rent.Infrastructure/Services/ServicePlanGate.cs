using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Infrastructure.Services;

/// <summary>
/// Asks the Service API — which holds the business's plan over all three areas — whether one more
/// rent item may go live, with the business's own sign-in. Refused: <see cref="PlanLimitException"/>.
/// No answer: refused too (fail closed), so an unreachable Service never lets a free business past
/// its limit. With no Service API configured (tests, a lone local run) there is no plan to check.
/// </summary>
public class ServicePlanGate(
    HttpClient http,
    IHttpContextAccessor httpContextAccessor,
    IOptions<ServiceApiSettings> settings,
    ILogger<ServicePlanGate> logger) : IServicePlanGate
{
    public const string Area = "Rent";

    /// <summary>Long enough for a sleeping Service API on a free plan to wake.</summary>
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(45);

    public async Task EnsureCanAddAsync(int liveHere, CancellationToken cancellationToken)
    {
        var baseUrl = settings.Value.BaseUrl;
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            return;
        }

        var authorization = httpContextAccessor.HttpContext?.Request.Headers.Authorization.ToString();
        if (string.IsNullOrWhiteSpace(authorization) || !AuthenticationHeaderValue.TryParse(authorization, out var header))
        {
            throw new DomainException(CouldNotCheck);
        }

        JsonElement data;
        try
        {
            using var request = new HttpRequestMessage(
                HttpMethod.Post, new Uri(new Uri(baseUrl.TrimEnd('/') + "/"), "api/v1/business/plan/can-add"))
            {
                Content = JsonContent.Create(new { area = Area, liveHere }),
            };
            request.Headers.Authorization = header;
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(Timeout);
            using var response = await http.SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Service API plan check answered {Status}", (int)response.StatusCode);
                throw new DomainException(CouldNotCheck);
            }

            using var json = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(timeout.Token), cancellationToken: timeout.Token);
            data = json.RootElement.GetProperty("data").Clone();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or KeyNotFoundException)
        {
            logger.LogWarning(ex, "Service API plan check failed");
            throw new DomainException(CouldNotCheck);
        }

        if (!data.TryGetProperty("allowed", out var allowed) || allowed.ValueKind != JsonValueKind.True)
        {
            var reason = data.TryGetProperty("reason", out var r) && r.ValueKind == JsonValueKind.String
                ? r.GetString()
                : null;
            throw new PlanLimitException(reason ?? "Your plan does not allow another live listing here.");
        }
    }

    private const string CouldNotCheck = "We couldn't check your plan just now. Try again in a minute.";
}
