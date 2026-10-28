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
    public const string Pattern = @"^[\w.\-]{2,}@[A-Za-z]{2,}$";

    public const string Hint = "A UPI address looks like name@bank, for example ravi@okhdfcbank.";

    public static bool IsValid(string? upiVpa) => upiVpa is not null && Regex().IsMatch(upiVpa);

    [GeneratedRegex(Pattern)]
    private static partial Regex Regex();
}
