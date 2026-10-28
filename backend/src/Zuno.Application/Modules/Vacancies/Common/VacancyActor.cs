using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>
/// Who is calling, as the profile id every vacancy rule is checked against. Read from the token, never
/// from the request, and fetched as a single column rather than a whole profile.
/// </summary>
public static class VacancyActor
{
    public static async Task<Guid> BusinessProfileIdAsync(
        ICurrentUserService currentUser, IApplicationDbContext dbContext, CancellationToken cancellationToken)
    {
        var userId = UserId(currentUser);

        var id = await dbContext.BusinessOwnerProfiles
            .Where(b => b.UserId == userId)
            .Select(b => (Guid?)b.Id)
            .FirstOrDefaultAsync(cancellationToken);

        return id ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);
    }

    public static async Task<Guid> WorkerProfileIdAsync(
        ICurrentUserService currentUser, IApplicationDbContext dbContext, CancellationToken cancellationToken)
    {
        var userId = UserId(currentUser);

        var id = await dbContext.WorkerProfiles
            .Where(w => w.UserId == userId)
            .Select(w => (Guid?)w.Id)
            .FirstOrDefaultAsync(cancellationToken);

        return id ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);
    }

    /// <summary>
    /// The business's own vacancy, tracked for writing. Someone else's is reported as not found rather
    /// than forbidden, so ids cannot be probed to learn which exist.
    /// </summary>
    public static async Task<Vacancy> OwnedVacancyAsync(
        IQueryable<Vacancy> query, Guid vacancyId, Guid businessProfileId, CancellationToken cancellationToken) =>
        await query.FirstOrDefaultAsync(
            v => v.Id == vacancyId && v.BusinessOwnerProfileId == businessProfileId, cancellationToken)
        ?? throw new EntityNotFoundException(nameof(Vacancy), vacancyId);

    private static Guid UserId(ICurrentUserService currentUser) =>
        currentUser.UserId ?? throw new UnauthorizedAccessException("User is not authenticated.");
}
