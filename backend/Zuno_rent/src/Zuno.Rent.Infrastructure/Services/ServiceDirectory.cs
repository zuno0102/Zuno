using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Infrastructure.Services;

/// <summary>Where the Service API is (section <c>ServiceApi</c>).</summary>
public class ServiceApiSettings
{
    public const string SectionName = "ServiceApi";

    /// <summary>e.g. <c>https://api.zuno.app</c>. Empty disables the lookups (they return null).</summary>
    public string BaseUrl { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 8;
}

/// <summary>
/// Asks the Service API about the signed-in user, sending on their own bearer token — so Rent learns
/// only what that user may see of themselves, and needs no secret of its own to do it.
/// </summary>
public class ServiceDirectory(
    HttpClient http,
    IHttpContextAccessor httpContextAccessor,
    IOptions<ServiceApiSettings> settings,
    ILogger<ServiceDirectory> logger) : IServiceDirectory
{
    private const string VerifiedStatus = "Verified";

    public async Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken)
    {
        var data = await GetAsync("api/v1/auth/me", cancellationToken);
        if (data is not { } user)
        {
            return null;
        }

        var name = $"{Text(user, "firstName")} {Text(user, "lastName")}".Trim();
        return new ServicePerson(name.Length == 0 ? "Customer" : name, Text(user, "phoneNumber"));
    }

    public async Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken)
    {
        var data = await GetAsync("api/v1/business/profile", cancellationToken);
        if (data is not { } profile || Text(profile, "businessName") is not { Length: > 0 } name)
        {
            return null;
        }

        return new ServiceBusiness(
            name,
            Text(profile, "logoUrl"),
            string.Equals(Text(profile, "verificationStatus"), VerifiedStatus, StringComparison.OrdinalIgnoreCase),
            Text(profile, "upiId"));
    }

    /// <summary>The <c>data</c> of the Service API's reply, or null on any failure — logged, never thrown.</summary>
    private async Task<JsonElement?> GetAsync(string path, CancellationToken cancellationToken)
    {
        var baseUrl = settings.Value.BaseUrl;
        var authorization = httpContextAccessor.HttpContext?.Request.Headers.Authorization.ToString();
        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(authorization)
            || !AuthenticationHeaderValue.TryParse(authorization, out var header))
        {
            return null;
        }

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, new Uri(new Uri(baseUrl.TrimEnd('/') + "/"), path));
            request.Headers.Authorization = header;
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(settings.Value.TimeoutSeconds));

            using var response = await http.SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Service API {Path} answered {Status}", path, (int)response.StatusCode);
                return null;
            }

            var body = await response.Content.ReadFromJsonAsync<JsonElement>(timeout.Token);
            return body.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Object ? data.Clone() : null;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(ex, "Service API {Path} could not be reached", path);
            return null;
        }
    }

    private static string? Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}
