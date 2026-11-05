using System.Text.RegularExpressions;

namespace Zuno.Application.Modules.Worker.Common;

/// <summary>What a UPI address looks like: name@handle. One rule for the form check and the payout check.</summary>
/// <remarks>
/// Loose on purpose: banks keep adding handles, and a strict list would start refusing valid
/// addresses the month after it was written. Whether the address really exists is the payout
/// provider's call — see <see cref="Common.Interfaces.IPayoutDestinationCheck"/>.
/// </remarks>
public static partial class UpiFormat
{
    /// <summary>
    /// The same rule as Rent's <c>RentalPaymentFields.UpiIdPattern</c> and the app's
    /// <c>upiIdPattern</c>: one ID saved here is one Rent accepts, so the QR made from it works.
    /// </summary>
    public const string Pattern = @"^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$";

    public const string Hint = "A UPI address looks like name@bank, for example ravi@okhdfcbank.";

    /// <summary>Longest address kept — the same for a worker's payout UPI and a business's UPI ID.</summary>
    public const int MaxLength = 100;

    /// <summary>One way of writing every address: trimmed and lower-case, as UPI treats them.</summary>
    public static string Normalize(string upiId) => upiId.Trim().ToLowerInvariant();

    public static bool IsValid(string? upiVpa) => upiVpa is not null && Regex().IsMatch(upiVpa);

    [GeneratedRegex(Pattern)]
    private static partial Regex Regex();
}
