using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.Business.Common;

/// <inheritdoc />
/// <remarks>
/// PLACEHOLDER: no rules yet, so every business passes. The validation rules are a later piece of
/// work; add them here (and only here) and both the admin's approval and auto-approval will enforce
/// them at once.
/// </remarks>
public sealed class BusinessVerificationCheck : IBusinessVerificationCheck
{
    public Task<IReadOnlyList<string>> ProblemsAsync(BusinessOwnerProfile profile, CancellationToken cancellationToken) =>
        Task.FromResult<IReadOnlyList<string>>([]);
}
