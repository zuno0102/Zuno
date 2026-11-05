using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Infrastructure.Services;

/// <inheritdoc />
/// <remarks>
/// Reads <c>GET /api/v1/rentals/reputation</c>, which the Rent API serves without sign-in. The answer
/// is read defensively: the list is accepted inside the usual <c>{ "data": { "items": [...] } }</c>
/// envelope or as a bare top-level <c>items</c>, and a row that cannot be read is skipped rather than
/// spoiling the rest. Any failure is logged and reported as null, so the stored figures stay put.
/// </remarks>
public class RentReputationClient(
    HttpClient httpClient,
    IOptions<RentApiSettings> settings,
    ILogger<RentReputationClient> logger) : IRentReputationClient
{
    /// <summary>The Rent API's reputation endpoint, relative to its base address.</summary>
    public const string ReputationPath = "api/v1/rentals/reputation";

    public async Task<IReadOnlyList<RentReputation>?> GetAllAsync(CancellationToken cancellationToken)
    {
        if (!settings.Value.IsConfigured)
        {
            return null;
        }

        try
        {
            using var response = await httpClient.GetAsync(ReputationPath, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "Rent reputation request answered {StatusCode}; keeping the stored Rent figures.",
                    (int)response.StatusCode);
                return null;
            }

            var json = await response.Content.ReadAsStringAsync(cancellationToken);
            var items = Parse(json);
            if (items is null)
            {
                logger.LogWarning("Rent reputation answer had no items list; keeping the stored Rent figures.");
            }

            return items;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException
            && !cancellationToken.IsCancellationRequested)
        {
            // Asleep past the time-out, unreachable, or answering nonsense. Next run tries again.
            logger.LogWarning(ex, "Rent reputation could not be read; keeping the stored Rent figures.");
            return null;
        }
    }

    /// <summary>
    /// The rows in a reputation answer, or null when it holds no items list at all. Accepts the list at
    /// <c>data.items</c> or at top-level <c>items</c>; property names are matched without regard to case.
    /// </summary>
    public static IReadOnlyList<RentReputation>? Parse(string json)
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var items = Property(root, "data") is { ValueKind: JsonValueKind.Object } data
            ? Property(data, "items")
            : null;
        items ??= Property(root, "items");

        if (items is not { ValueKind: JsonValueKind.Array } list)
        {
            return null;
        }

        var rows = new List<RentReputation>(list.GetArrayLength());
        foreach (var item in list.EnumerateArray())
        {
            if (Row(item) is { } row)
            {
                rows.Add(row);
            }
        }

        return rows;
    }

    private static RentReputation? Row(JsonElement item)
    {
        if (item.ValueKind != JsonValueKind.Object
            || Property(item, "ownerUserId") is not { } owner
            || owner.ValueKind != JsonValueKind.String
            || !Guid.TryParse(owner.GetString(), out var ownerUserId))
        {
            return null;
        }

        var ratingSum = Decimal(Property(item, "ratingSum"));
        var ratingCount = Whole(Property(item, "ratingCount"));
        var successful = Whole(Property(item, "successfulOrders"));

        // Negative figures can only be a fault at the other end; trusting them would pull a rating down.
        if (ratingSum is null or < 0m || ratingCount is null or < 0 || successful is null or < 0)
        {
            return null;
        }

        return new RentReputation(ownerUserId, ratingSum.Value, ratingCount.Value, successful.Value);
    }

    private static JsonElement? Property(JsonElement element, string name)
    {
        foreach (var property in element.EnumerateObject())
        {
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase))
            {
                return property.Value;
            }
        }

        return null;
    }

    private static decimal? Decimal(JsonElement? value) => value switch
    {
        { ValueKind: JsonValueKind.Number } n when n.TryGetDecimal(out var d) => d,
        { ValueKind: JsonValueKind.String } s when decimal.TryParse(
            s.GetString(), NumberStyles.Number, CultureInfo.InvariantCulture, out var d) => d,
        { ValueKind: JsonValueKind.Null } or null => 0m,
        _ => null,
    };

    private static int? Whole(JsonElement? value) => value switch
    {
        { ValueKind: JsonValueKind.Number } n when n.TryGetInt32(out var i) => i,
        { ValueKind: JsonValueKind.Null } or null => 0,
        _ => null,
    };
}
