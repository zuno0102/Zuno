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
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Orders;

namespace Zuno.Marketplace.Infrastructure.Services;

/// <summary>The gateway account Marketplace takes customers' online payments with (section <c>MarketplacePayments</c>).</summary>
/// <remarks>
/// The key secret is a secret: user-secrets or the host's settings, never a committed file. Without
/// keys online pay is simply unavailable — customers order with cash on delivery — and the API still starts.
/// </remarks>
public class MarketplacePaymentSettings
{
    public const string SectionName = "MarketplacePayments";

    public string KeyId { get; set; } = string.Empty;

    public string KeySecret { get; set; } = string.Empty;

    /// <summary>Overridable so tests can point at a stub.</summary>
    public string BaseUrl { get; set; } = "https://api.razorpay.com/v1/";

    /// <summary>
    /// Takes no real money: payments are accepted unchecked, so the flow can be walked without a
    /// merchant account. Refused outside Development when the API starts.
    /// </summary>
    public bool SimulateCollection { get; set; }
}

/// <summary>Razorpay for Marketplace orders: the same order and signature scheme Rent and Service use.</summary>
public class RazorpayMarketplaceGateway(
    HttpClient http, IOptions<MarketplacePaymentSettings> options, ILogger<RazorpayMarketplaceGateway> logger) : IMarketplacePaymentGateway
{
    private readonly MarketplacePaymentSettings _settings = options.Value;

    public bool IsSimulated => _settings.SimulateCollection;

    public bool IsReady =>
        IsSimulated || (!string.IsNullOrWhiteSpace(_settings.KeyId) && !string.IsNullOrWhiteSpace(_settings.KeySecret));

    public string KeyId => IsSimulated ? string.Empty : _settings.KeyId;

    public async Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken)
    {
        var paise = Paise(amount);
        if (IsSimulated)
        {
            logger.LogWarning(
                "[MarketplacePayments] SIMULATED order for {Paise} paise ({Description}). NO REAL MONEY — SimulateCollection is on.",
                paise, description);
            return $"sim_{receipt}";
        }

        // The receipt is Razorpay's idempotency handle: the same one returns the same order.
        var json = await SendAsync(HttpMethod.Post, "orders", new Dictionary<string, object?>
        {
            ["amount"] = paise,
            ["currency"] = "INR",
            ["receipt"] = receipt,
            ["notes"] = new Dictionary<string, string> { ["description"] = description },
        }, "start this payment", cancellationToken);
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

    public async Task<string?> FindCapturedPaymentAsync(string providerOrderId, CancellationToken cancellationToken)
    {
        if (IsSimulated || !IsReady || string.IsNullOrWhiteSpace(providerOrderId))
        {
            return null;
        }

        // Not answered throws: "could not ask" must never read as "not paid", or a paid order would be let go.
        using var json = await SendAsync(
            HttpMethod.Get, $"orders/{Uri.EscapeDataString(providerOrderId)}/payments", null, "read this order's payments", cancellationToken);

        // Only "captured" is money in hand; "authorized" may still be given back by the bank.
        foreach (var payment in json.RootElement.GetProperty("items").EnumerateArray())
        {
            if (payment.GetProperty("status").GetString() == "captured")
            {
                return payment.GetProperty("id").GetString();
            }
        }

        return null;
    }

    public async Task<string> RefundAsync(string paymentId, decimal amount, CancellationToken cancellationToken)
    {
        if (IsSimulated)
        {
            logger.LogWarning("[MarketplacePayments] SIMULATED refund of {Payment}. NO REAL MONEY.", paymentId);
            return $"sim_rfnd_{paymentId}";
        }

        using var json = await SendAsync(
            HttpMethod.Post,
            $"payments/{Uri.EscapeDataString(paymentId)}/refund",
            new Dictionary<string, object?> { ["amount"] = Paise(amount) },
            "give this payment back",
            cancellationToken);
        return json.RootElement.GetProperty("id").GetString()
            ?? throw new InvalidOperationException("The payment gateway returned a refund without an id.");
    }

    private async Task<JsonDocument> SendAsync(
        HttpMethod method, string path, object? body, string what, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(method, path) { Content = body is null ? null : JsonContent.Create(body) };
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_settings.KeyId}:{_settings.KeySecret}")));

        using var response = await http.SendAsync(request, cancellationToken);
        var text = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogError("[MarketplacePayments] Razorpay refused to {What} ({Status}): {Body}", what, (int)response.StatusCode, text);
            throw new HttpRequestException($"The payment gateway refused to {what}.");
        }

        return JsonDocument.Parse(text);
    }

    private static long Paise(decimal amount) => (long)decimal.Round(amount * 100, MidpointRounding.AwayFromZero);
}

/// <summary>
/// Every minute: lets go of online orders not paid in time (stock back), closes delivered orders
/// whose review days have passed, and retries refunds the gateway did not take the first time.
/// </summary>
public class MarketplaceOrderJobService(IServiceScopeFactory scopes, ILogger<MarketplaceOrderJobService> logger) : BackgroundService
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
                var done = await scope.ServiceProvider.GetRequiredService<ISender>()
                    .Send(new RunMarketplaceOrderJobsCommand(), stoppingToken);
                if (done.Total > 0)
                {
                    logger.LogInformation(
                        "Marketplace orders: {Lapsed} unpaid let go, {Closed} closed after delivery, {Refunded} refunded.",
                        done.Lapsed, done.Closed, done.Refunded);
                }
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                // A bad minute must not stop the job; the next tick tries again.
                logger.LogError(exception, "The Marketplace order job failed; it will try again.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
