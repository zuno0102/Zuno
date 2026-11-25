using System.Net.Http.Json;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Enums;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Reads and pauses a business's listings in the Rent and Marketplace APIs through their internal
/// endpoints, with the key the three APIs share. Any failure — not set up, unreachable, refused — is
/// an <see cref="AreaUnavailableException"/>: the caller decides, and a plan check then refuses.
/// </summary>
public class AreaListingsClient(
    IHttpClientFactory httpClientFactory,
    IOptions<RentApiSettings> rentApi,
    IOptions<MarketplaceApiSettings> marketplaceApi,
    IOptions<InternalApiSettings> internalApi) : IAreaListings
{
    public const string RentClient = "rent-internal";

    public const string MarketplaceClient = "marketplace-internal";

    private sealed record LiveListingRow(Guid Id, DateTimeOffset CreatedDate);

    public async Task<IReadOnlyList<AreaListing>> LiveAsync(ListingArea area, Guid ownerUserId, CancellationToken cancellationToken)
    {
        var rows = await SendAsync<List<LiveListingRow>>(area, HttpMethod.Get, $"api/v1/internal/owners/{ownerUserId}/live-listings", null, cancellationToken);
        return [.. (rows ?? []).Select(r => new AreaListing(r.Id, r.CreatedDate))];
    }

    public Task PauseAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken) =>
        SendAsync<object>(area, HttpMethod.Post, $"api/v1/internal/owners/{ownerUserId}/pause", new { ids = listingIds }, cancellationToken);

    public Task ResumeAsync(ListingArea area, Guid ownerUserId, IReadOnlyCollection<Guid> listingIds, CancellationToken cancellationToken) =>
        SendAsync<object>(area, HttpMethod.Post, $"api/v1/internal/owners/{ownerUserId}/resume", new { ids = listingIds }, cancellationToken);

    private async Task<T?> SendAsync<T>(ListingArea area, HttpMethod method, string path, object? body, CancellationToken cancellationToken)
    {
        var configured = area switch
        {
            ListingArea.Rent => rentApi.Value.IsConfigured,
            ListingArea.Marketplace => marketplaceApi.Value.IsConfigured,
            _ => false,
        };
        if (!configured || !internalApi.Value.IsConfigured)
        {
            throw new AreaUnavailableException(area);
        }

        var client = httpClientFactory.CreateClient(area == ListingArea.Rent ? RentClient : MarketplaceClient);

        // A server on a free plan sleeps when idle and answers 502/503 (or not at all) for the few
        // seconds it takes to wake. Every call here is safe to repeat (a read, or setting listings to a
        // state), so it is asked again until it answers or the wait is up; only then is the area
        // unavailable and a plan check refused.
        var giveUpAt = DateTimeOffset.UtcNow + WakeUpWait;
        for (var attempt = 1; ; attempt++)
        {
            using var request = new HttpRequestMessage(method, path);
            request.Headers.Add(InternalApiSettings.HeaderName, internalApi.Value.Key);
            if (body is not null)
            {
                request.Content = JsonContent.Create(body);
            }

            try
            {
                using var response = await client.SendAsync(request, cancellationToken);
                if (IsWakingUp(response.StatusCode) && DateTimeOffset.UtcNow + RetryDelay(attempt) < giveUpAt)
                {
                    await Task.Delay(RetryDelay(attempt), cancellationToken);
                    continue;
                }

                if (!response.IsSuccessStatusCode)
                {
                    throw new AreaUnavailableException(area);
                }

                if (response.StatusCode == System.Net.HttpStatusCode.NoContent)
                {
                    return default;
                }

                // Answers come wrapped as { data: … } like every Zuno API response.
                var envelope = await response.Content.ReadFromJsonAsync<Envelope<T>>(cancellationToken);
                return envelope is null ? default : envelope.Data;
            }
            catch (Exception ex) when (
                ex is HttpRequestException or TaskCanceledException
                && !cancellationToken.IsCancellationRequested
                && DateTimeOffset.UtcNow + RetryDelay(attempt) < giveUpAt)
            {
                await Task.Delay(RetryDelay(attempt), cancellationToken);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
            {
                throw new AreaUnavailableException(area, ex);
            }
        }
    }

    /// <summary>How long a sleeping Rent or Marketplace API is given to wake before the area counts as unavailable.</summary>
    public static readonly TimeSpan WakeUpWait = TimeSpan.FromSeconds(45);

    private static bool IsWakingUp(System.Net.HttpStatusCode status) =>
        status is System.Net.HttpStatusCode.BadGateway
            or System.Net.HttpStatusCode.ServiceUnavailable
            or System.Net.HttpStatusCode.GatewayTimeout
            or System.Net.HttpStatusCode.TooManyRequests;

    /// <summary>2 s, 4 s, then every 6 s.</summary>
    private static TimeSpan RetryDelay(int attempt) => TimeSpan.FromSeconds(Math.Min(6, attempt * 2));

    private sealed record Envelope<T>(T? Data);
}
