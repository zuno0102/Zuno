using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// Moves real money through Razorpay: an order the business pays against, then a payout to each
/// worker.
/// </summary>
/// <remarks>
/// The two legs are two different Razorpay products. Collection is the payment gateway, which
/// the <c>rzp_test_…</c> keys cover. Disbursement is <b>RazorpayX</b>, which needs its own
/// onboarding and a funded account number — so a payout attempted without
/// <see cref="RazorpaySettings.PayoutAccountNumber"/> is refused here with a clear reason rather
/// than sent off to be rejected with an opaque one.
///
/// Amounts cross the wire in paise, as integers. Rupees are never sent as a decimal: binary
/// floating point cannot represent ₹0.10 exactly, and rounding drift in a payment system shows
/// up as money that does not reconcile.
/// </remarks>
public class RazorpayPayoutProvider(
    HttpClient httpClient,
    IOptions<RazorpaySettings> settings,
    ILogger<RazorpayPayoutProvider> logger) : IPayoutProvider
{
    private readonly RazorpaySettings _settings = settings.Value;

    public string Name => "Razorpay";

    /// <summary>Paise, as an integer. Away-from-zero so a half-paisa never rounds in our favour.</summary>
    private static long ToPaise(decimal amount) =>
        (long)Math.Round(amount * 100, MidpointRounding.AwayFromZero);

    public async Task<PayoutCollectionOrder> CreateCollectionOrderAsync(
        decimal amount,
        string idempotencyKey,
        string description,
        CancellationToken cancellationToken = default)
    {
        var paise = ToPaise(amount);

        // Nothing to collect, so no order to raise. Returning an empty id rather than a fake one
        // is deliberate: the confirm step skips signature checking exactly when there is no
        // order, and the pay sheet skips Checkout for the same reason. A made-up id would send
        // both down the real path looking for money that was never charged.
        //
        // Only reachable in Development — DependencyInjection refuses this anywhere else — so it
        // cannot become a way to mark a live job paid without paying.
        if (_settings.SimulateCollection)
        {
            logger.LogWarning(
                "[Razorpay] SIMULATED collection of {Paise} paise ({Description}). NO REAL "
                + "MONEY COLLECTED — Razorpay:SimulateCollection is on.",
                paise, description);

            return new PayoutCollectionOrder(string.Empty, paise);
        }

        // "receipt" is Razorpay's own idempotency handle for orders — the same receipt returns
        // the same order rather than creating a second charge for the same wages.
        var payload = new Dictionary<string, object?>
        {
            ["amount"] = paise,
            ["currency"] = "INR",
            ["receipt"] = idempotencyKey,
            ["notes"] = new Dictionary<string, string> { ["description"] = description },
        };

        using var response = await PostAsync("orders", payload, cancellationToken);
        var json = await ReadAsync(response, "create collection order", cancellationToken);

        var orderId = json.GetProperty("id").GetString()
            ?? throw new InvalidOperationException("Razorpay returned an order without an id.");

        logger.LogInformation(
            "[Razorpay] Order {OrderId} created for {Paise} paise (receipt {Receipt}).",
            orderId, paise, idempotencyKey);

        return new PayoutCollectionOrder(orderId, paise);
    }

    public async Task<PayoutInstructionResult> CreatePayoutAsync(
        PayoutDestination destination,
        decimal amount,
        string idempotencyKey,
        string narration,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(destination.UpiVpa)
            && string.IsNullOrWhiteSpace(destination.AccountNumber))
        {
            // Checked before the simulation branch on purpose: a worker with nowhere to be paid
            // must fail in simulation too, or the flag would hide a real data fault.
            return new PayoutInstructionResult(
                null, false, "No UPI address or bank account on file for this worker.");
        }

        if (_settings.SimulatePayouts)
        {
            var simulatedId = $"sim_payout_{Guid.NewGuid():N}";

            logger.LogWarning(
                "[Razorpay] SIMULATED payout {PayoutId}: {Amount} to {Worker} ({Destination}). "
                + "NO REAL MONEY MOVED — Razorpay:SimulatePayouts is on.",
                simulatedId, amount, destination.WorkerName,
                destination.UpiVpa ?? destination.AccountNumber);

            return new PayoutInstructionResult(simulatedId, true, null);
        }

        if (!_settings.CanDisburse)
        {
            return new PayoutInstructionResult(
                null,
                false,
                "Payouts are not activated on this Razorpay account. RazorpayX payouts must be "
                + "switched on and an account number configured before wages can be sent — the "
                + "payment-gateway keys alone cannot disburse.");
        }

        var payload = BuildPayoutPayload(destination, amount, narration);

        try
        {
            // Razorpay honours X-Payout-Idempotency on this endpoint, so a retried request
            // returns the original payout instead of paying a worker twice.
            using var request = new HttpRequestMessage(HttpMethod.Post, "payouts")
            {
                Content = JsonContent.Create(payload),
            };
            request.Headers.Add("X-Payout-Idempotency", idempotencyKey);

            using var response = await httpClient.SendAsync(request, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var reason = ExtractError(body);
                logger.LogWarning(
                    "[Razorpay] Payout rejected for {Worker}: {Status} {Reason}",
                    destination.WorkerName, (int)response.StatusCode, reason);
                return new PayoutInstructionResult(null, false, reason);
            }

            using var json = JsonDocument.Parse(body);
            var payoutId = json.RootElement.GetProperty("id").GetString();

            logger.LogInformation(
                "[Razorpay] Payout {PayoutId} of {Amount} accepted for {Worker}.",
                payoutId, amount, destination.WorkerName);

            return new PayoutInstructionResult(payoutId, true, null);
        }
        catch (HttpRequestException e)
        {
            // A network fault is not a refusal. Reported as a failure so the item stays
            // retryable, and never as a success, which would strand a worker unpaid.
            logger.LogError(e, "[Razorpay] Could not reach Razorpay for {Worker}.", destination.WorkerName);
            return new PayoutInstructionResult(
                null, false, "Could not reach Razorpay. The payment was not sent — retry it.");
        }
    }

    private Dictionary<string, object?> BuildPayoutPayload(
        PayoutDestination destination,
        decimal amount,
        string narration)
    {
        var useUpi = !string.IsNullOrWhiteSpace(destination.UpiVpa);

        var fundAccount = destination.ProviderFundAccountId is { Length: > 0 } existing
            // A fund account already registered with Razorpay is reused, so a worker's details
            // are not re-registered on every job.
            ? new Dictionary<string, object?> { ["id"] = existing }
            : new Dictionary<string, object?>
            {
                ["account_type"] = useUpi ? "vpa" : "bank_account",
                ["contact"] = new Dictionary<string, object?>
                {
                    ["name"] = destination.WorkerName,
                    ["type"] = "employee",
                },
                [useUpi ? "vpa" : "bank_account"] = useUpi
                    ? new Dictionary<string, object?> { ["address"] = destination.UpiVpa }
                    : new Dictionary<string, object?>
                    {
                        ["name"] = destination.WorkerName,
                        ["ifsc"] = destination.IfscCode,
                        ["account_number"] = destination.AccountNumber,
                    },
            };

        return new Dictionary<string, object?>
        {
            ["account_number"] = _settings.PayoutAccountNumber,
            ["amount"] = ToPaise(amount),
            ["currency"] = "INR",
            ["mode"] = useUpi ? "UPI" : "IMPS",
            ["purpose"] = "salary",
            // Razorpay queues rather than rejecting when the account is briefly short of funds.
            ["queue_if_low_balance"] = true,
            // Shown on the worker's bank statement; capped by Razorpay at 30 characters.
            ["narration"] = narration.Length > 30 ? narration[..30] : narration,
            ["fund_account"] = fundAccount,
        };
    }


    public bool VerifyPaymentSignature(string orderId, string paymentId, string signature)
    {
        if (string.IsNullOrWhiteSpace(orderId)
            || string.IsNullOrWhiteSpace(paymentId)
            || string.IsNullOrWhiteSpace(signature))
        {
            return false;
        }

        // Razorpay signs "order_id|payment_id" with the key secret. Recomputing it here is what
        // proves the browser really completed a payment, rather than simply saying it did.
        var expected = Hmac(_settings.KeySecret, $"{orderId}|{paymentId}");

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(signature));
    }


    /// <summary>Razorpay's signature scheme: HMAC-SHA256, hex encoded, lower case.</summary>
    private static string Hmac(string secret, string payload) =>
        Convert.ToHexString(
                HMACSHA256.HashData(
                    Encoding.UTF8.GetBytes(secret),
                    Encoding.UTF8.GetBytes(payload)))
            .ToLower(CultureInfo.InvariantCulture);

    private async Task<HttpResponseMessage> PostAsync(
        string path,
        Dictionary<string, object?> payload,
        CancellationToken cancellationToken) =>
        await httpClient.PostAsJsonAsync(path, payload, cancellationToken);

    private static async Task<JsonElement> ReadAsync(
        HttpResponseMessage response,
        string what,
        CancellationToken cancellationToken)
    {
        var body = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Razorpay could not {what}: {ExtractError(body)}");
        }

        return JsonDocument.Parse(body).RootElement.Clone();
    }

    /// <summary>Razorpay's own description of what went wrong, kept verbatim for the business.</summary>
    private static string ExtractError(string body)
    {
        try
        {
            using var json = JsonDocument.Parse(body);
            if (json.RootElement.TryGetProperty("error", out var error)
                && error.TryGetProperty("description", out var description))
            {
                return description.GetString() ?? body;
            }
        }
        catch (JsonException)
        {
            // Not JSON — fall through and surface whatever came back.
        }

        return string.IsNullOrWhiteSpace(body) ? "Razorpay returned no detail." : body;
    }

    /// <summary>Basic auth, exactly as Razorpay's API expects: key id as user, secret as password.</summary>
    public static AuthenticationHeaderValue BuildAuthHeader(RazorpaySettings settings) =>
        new("Basic", Convert.ToBase64String(
            Encoding.UTF8.GetBytes($"{settings.KeyId}:{settings.KeySecret}")));
}
