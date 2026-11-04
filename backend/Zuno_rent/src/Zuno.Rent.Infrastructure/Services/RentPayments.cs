using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Orders;

namespace Zuno.Rent.Infrastructure.Services;

/// <summary>
/// The payment gateway account Rent takes customers' online payments with (section <c>RentPayments</c>).
/// </summary>
/// <remarks>
/// The key secret is a secret: user-secrets or the host's settings, never a committed file. Without
/// keys online payment is simply unavailable — customers are told to pay the business directly — so
/// the API still starts.
/// </remarks>
public class RentPaymentSettings
{
    public const string SectionName = "RentPayments";

    public string KeyId { get; set; } = string.Empty;

    public string KeySecret { get; set; } = string.Empty;

    /// <summary>Overridable so tests can point at a stub.</summary>
    public string BaseUrl { get; set; } = "https://api.razorpay.com/v1/";

    /// <summary>
    /// Takes no real money: the app skips the payment window and payments are accepted unchecked, so
    /// the whole flow can be walked without a merchant account. Off by default, even in Development —
    /// turn it on only for scripted runs (<c>RentPayments__SimulateCollection=true</c>). Refused
    /// outside Development when the API starts.
    /// </summary>
    public bool SimulateCollection { get; set; }
}

/// <summary>
/// Razorpay for Rent: an order per payment attempt, and the signature check that proves a payment —
/// the same scheme the Service module uses for its own collections.
/// </summary>
public class RazorpayRentGateway(HttpClient http, IOptions<RentPaymentSettings> options, ILogger<RazorpayRentGateway> logger)
    : IRentPaymentGateway
{
    private readonly RentPaymentSettings _settings = options.Value;

    public bool IsSimulated => _settings.SimulateCollection;

    public bool IsReady =>
        IsSimulated || (!string.IsNullOrWhiteSpace(_settings.KeyId) && !string.IsNullOrWhiteSpace(_settings.KeySecret));

    public string KeyId => IsSimulated ? string.Empty : _settings.KeyId;

    public async Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken)
    {
        var paise = (long)decimal.Round(amount * 100, MidpointRounding.AwayFromZero);

        if (IsSimulated)
        {
            logger.LogWarning(
                "[RentPayments] SIMULATED order for {Paise} paise ({Description}). NO REAL MONEY — RentPayments:SimulateCollection is on.",
                paise, description);
            return $"sim_{receipt}";
        }

        // The receipt is Razorpay's idempotency handle: the same one returns the same order.
        using var request = new HttpRequestMessage(HttpMethod.Post, "orders")
        {
            Content = JsonContent.Create(new Dictionary<string, object?>
            {
                ["amount"] = paise,
                ["currency"] = "INR",
                ["receipt"] = receipt,
                ["notes"] = new Dictionary<string, string> { ["description"] = description },
            }),
        };
        request.Headers.Authorization = AuthHeader(_settings);

        using var response = await http.SendAsync(request, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogError("[RentPayments] Razorpay refused an order ({Status}): {Body}", (int)response.StatusCode, body);
            throw new InvalidOperationException("The payment gateway refused to start this payment.");
        }

        using var json = JsonDocument.Parse(body);
        return json.RootElement.GetProperty("id").GetString()
            ?? throw new InvalidOperationException("The payment gateway returned an order without an id.");
    }

    public bool VerifySignature(string providerOrderId, string paymentId, string signature)
    {
        if (IsSimulated)
        {
            // Only a simulated order can be "paid" this way, and simulation exists only in Development.
            return providerOrderId.StartsWith("sim_", StringComparison.Ordinal);
        }

        if (string.IsNullOrWhiteSpace(providerOrderId) || string.IsNullOrWhiteSpace(paymentId) || string.IsNullOrWhiteSpace(signature))
        {
            return false;
        }

        // Razorpay signs "order_id|payment_id" with the key secret, HMAC-SHA256, hex, lower case.
        var expected = Convert.ToHexString(
                HMACSHA256.HashData(Encoding.UTF8.GetBytes(_settings.KeySecret), Encoding.UTF8.GetBytes($"{providerOrderId}|{paymentId}")))
            .ToLowerInvariant();

        return CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(signature));
    }

    private static AuthenticationHeaderValue AuthHeader(RentPaymentSettings settings) =>
        new("Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes($"{settings.KeyId}:{settings.KeySecret}")));
}

/// <summary>
/// Every minute, lets go of app bookings whose advance was not paid in time. Availability already
/// ignores a lapsed hold; this makes the order itself say "Cancelled".
/// </summary>
public class AdvanceLapseService(IServiceScopeFactory scopes, ILogger<AdvanceLapseService> logger) : BackgroundService
{
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);
        do
        {
            try
            {
                using var scope = scopes.CreateScope();
                var lapsed = await scope.ServiceProvider.GetRequiredService<ISender>()
                    .Send(new LapseRentalAdvancesCommand(), stoppingToken);
                if (lapsed > 0)
                {
                    logger.LogInformation("Let go {Count} rent booking(s) whose advance was not paid in time.", lapsed);
                }
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                // A bad minute must not stop the job; the next tick tries again.
                logger.LogError(exception, "The rent advance lapse job failed; it will try again.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
