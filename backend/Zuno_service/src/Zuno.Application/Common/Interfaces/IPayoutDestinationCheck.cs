namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Whether a worker's UPI address can be paid to. Run when an address is added or changed — never on
/// an unchanged one — and the worker can be paid only once it passes.
/// </summary>
/// <remarks>
/// The one place payout verification happens. Today it is a format check
/// (<c>PayoutDestinationCheck</c>); the real check — asking the payout provider whether the address
/// exists — replaces its body later, and nothing else changes.
/// </remarks>
public interface IPayoutDestinationCheck
{
    Task<PayoutCheckResult> CheckUpiAsync(string upiVpa, CancellationToken cancellationToken);
}

/// <param name="Reason">Why it failed, in words the worker can act on. Null when it passed.</param>
public sealed record PayoutCheckResult(bool IsVerified, string? Reason = null);
