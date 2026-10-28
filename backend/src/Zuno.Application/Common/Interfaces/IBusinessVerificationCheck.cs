using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// What a business must satisfy before it can be approved and shown to customers — by an admin, or
/// automatically when <c>Verification:AutoVerifyBusinesses</c> is on.
/// </summary>
/// <remarks>
/// The one gate both approval paths go through, so the rules are written once and neither path can
/// skip them. The rules themselves (documents, GST, address and so on) are to be decided; until then
/// the check passes every business — see <c>BusinessVerificationCheck</c>.
/// </remarks>
public interface IBusinessVerificationCheck
{
    /// <summary>Why this business cannot be approved yet, in words an admin or owner can act on. Empty when it can.</summary>
    Task<IReadOnlyList<string>> ProblemsAsync(BusinessOwnerProfile profile, CancellationToken cancellationToken);
}
