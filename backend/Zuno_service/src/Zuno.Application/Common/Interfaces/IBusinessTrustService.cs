using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Builds the two-sided trust record for a business.
/// </summary>
/// <remarks>
/// Computed on read rather than denormalised onto the profile. These figures appear on one
/// business at a time — an owner's own profile, or the page a worker opens before applying —
/// not on every row of a search result, so the cost is paid once and the numbers can never
/// drift from the rows they describe.
/// </remarks>
public interface IBusinessTrustService
{
    Task<BusinessTrustDto> GetAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken = default);
}
