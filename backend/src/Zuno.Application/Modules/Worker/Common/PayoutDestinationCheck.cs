using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Worker.Common;

/// <inheritdoc />
/// <remarks>
/// PLACEHOLDER until the real UPI check is built: verified when the address is well formed. Replace
/// the body with the payout provider's validation (Razorpay /fund_accounts/validations) and every
/// caller — saving a UPI, paying the crew — follows.
/// </remarks>
public sealed class PayoutDestinationCheck : IPayoutDestinationCheck
{
    public Task<PayoutCheckResult> CheckUpiAsync(string upiVpa, CancellationToken cancellationToken) =>
        Task.FromResult(UpiFormat.IsValid(upiVpa)
            ? new PayoutCheckResult(true)
            : new PayoutCheckResult(false, UpiFormat.Hint));
}
