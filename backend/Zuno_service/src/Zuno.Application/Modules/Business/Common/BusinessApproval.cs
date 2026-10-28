using Microsoft.Extensions.Options;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Business.Common;

/// <summary>
/// The two ways a business becomes Verified, sharing one validation step.
/// </summary>
/// <remarks>
/// <list type="bullet">
///   <item><b>Auto-approve on</b> (<c>Verification:AutoVerifyBusinesses</c>): a business that passes
///   <see cref="IBusinessVerificationCheck"/> is approved on sign-up, or on its next sign-in if it was
///   still pending. One that does not pass stays pending for an admin.</item>
///   <item><b>Auto-approve off</b> (production): every business waits for an admin, and the admin's
///   approval is refused while the check still finds problems.</item>
/// </list>
/// </remarks>
public sealed class BusinessApproval(
    IBusinessVerificationCheck verificationCheck,
    IOptions<VerificationSettings> verificationSettings,
    IDateTimeProvider dateTimeProvider)
{
    /// <summary>Whether businesses are approved without an admin (after passing the check).</summary>
    public bool IsAutoApproveOn => verificationSettings.Value.AutoVerifyBusinesses;

    /// <summary>Approves a pending business when auto-approval is on and it passes the check. Says whether it did.</summary>
    public async Task<bool> TryAutoApproveAsync(BusinessOwnerProfile profile, CancellationToken cancellationToken)
    {
        if (!verificationSettings.Value.AutoVerifyBusinesses
            || profile.VerificationStatus != VerificationStatus.Pending
            || (await verificationCheck.ProblemsAsync(profile, cancellationToken)).Count > 0)
        {
            return false;
        }

        Approve(profile);
        return true;
    }

    /// <summary>An admin's decision. Approval is refused, with the reasons, while the check finds problems.</summary>
    public async Task<IReadOnlyList<string>> DecideAsync(
        BusinessOwnerProfile profile, bool approve, CancellationToken cancellationToken)
    {
        if (!approve)
        {
            profile.VerificationStatus = VerificationStatus.Rejected;
            // Stamped only on approval: a rejection is not a verification date.
            profile.VerifiedAt = null;
            return [];
        }

        var problems = await verificationCheck.ProblemsAsync(profile, cancellationToken);
        if (problems.Count == 0)
        {
            Approve(profile);
        }

        return problems;
    }

    private void Approve(BusinessOwnerProfile profile)
    {
        profile.VerificationStatus = VerificationStatus.Verified;
        profile.VerifiedAt = dateTimeProvider.UtcNow;
    }
}
