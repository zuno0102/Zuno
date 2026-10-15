using System.ComponentModel.DataAnnotations;

namespace Zuno.Application.Common.Settings;

/// <summary>
/// Credentials and account details for Razorpay.
/// </summary>
/// <remarks>
/// Every value here is a secret and belongs in user-secrets or the host's configuration store,
/// never in a committed <c>appsettings.json</c> — the same rule the signing key and connection
/// string already follow.
/// </remarks>
public class RazorpaySettings
{
    public const string SectionName = "Razorpay";

    [Required(AllowEmptyStrings = false)]
    public string KeyId { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string KeySecret { get; set; } = string.Empty;

    /// <summary>
    /// The secret configured against the webhook in the Razorpay dashboard. Without it a
    /// webhook cannot be authenticated, and an unauthenticated webhook could mark unpaid
    /// workers as paid — so payouts refuse to resolve until this is set.
    /// </summary>
    public string? WebhookSecret { get; set; }

    /// <summary>
    /// The RazorpayX account the money is sent <em>from</em>, in the form <c>2323230000000000</c>.
    /// </summary>
    /// <remarks>
    /// Payouts are a RazorpayX product, separate from the payment gateway that collects money.
    /// Standard <c>rzp_test_…</c> gateway keys cannot make payouts, so until a RazorpayX account
    /// is onboarded and this is filled in, disbursement will be rejected by Razorpay.
    /// </remarks>
    public string? PayoutAccountNumber { get; set; }

    /// <summary>Base address, overridable so tests can point at a stub.</summary>
    public string BaseUrl { get; set; } = "https://api.razorpay.com/v1/";

    /// <summary>
    /// Pretends payouts succeed instead of calling RazorpayX, so the settlement flow can be
    /// exercised before payouts are activated on the account.
    /// </summary>
    /// <remarks>
    /// Off unless switched on deliberately, refused outright outside Development, and every
    /// simulated payout is logged as a warning naming the worker and amount. The point of all
    /// three is that this can never be mistaken for real money — the previous stand-in was
    /// registered silently and would have shipped to production looking like it worked.
    /// </remarks>
    public bool SimulatePayouts { get; set; }

    /// <summary>
    /// Skips raising a Razorpay order, so a pay run needs no Checkout and no signature.
    /// </summary>
    /// <remarks>
    /// Separate from <see cref="SimulatePayouts"/> because the two are different products and can
    /// be available independently. Test gateway keys collect money perfectly well, so collection
    /// can be real long before RazorpayX payouts are onboarded.
    /// <para>
    /// Its real use is the phone: Checkout is a browser window and the app carries no native SDK,
    /// so with this off a business can only pay from the web. Turn it on to walk the whole chain
    /// on a device.
    /// </para>
    /// <para>Refused outside Development, for the same reason simulated payouts are.</para>
    /// </remarks>
    public bool SimulateCollection { get; set; }

    /// <summary>Whether there is enough configuration to attempt a payout at all.</summary>
    public bool CanDisburse =>
        SimulatePayouts || !string.IsNullOrWhiteSpace(PayoutAccountNumber);
}
