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
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Add(InternalApiSettings.HeaderName, internalApi.Value.Key);
        if (body is not null)
        {
            request.Content = JsonContent.Create(body);
        }

        try
        {
            using var response = await client.SendAsync(request, cancellationToken);
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
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            throw new AreaUnavailableException(area, ex);
        }
    }

    private sealed record Envelope<T>(T? Data);
}
