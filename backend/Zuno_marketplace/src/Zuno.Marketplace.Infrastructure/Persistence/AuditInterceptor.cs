using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Common;

namespace Zuno.Marketplace.Infrastructure.Persistence;

/// <summary>
/// Stamps who and when on every save, and turns a delete into a soft delete — the row stays,
/// marked, and the context's filter hides it.
/// </summary>
public class AuditInterceptor(ICurrentUser currentUser, TimeProvider clock) : SaveChangesInterceptor
{
    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        Stamp(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        Stamp(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void Stamp(DbContext? context)
    {
        if (context is null)
        {
            return;
        }

        var now = clock.GetUtcNow();
        var userId = currentUser.UserId;

        foreach (var entry in context.ChangeTracker.Entries<IAuditableEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedDate = now;
                    entry.Entity.CreatedBy = userId;
                    break;

                case EntityState.Modified:
                    entry.Entity.ModifiedDate = now;
                    entry.Entity.ModifiedBy = userId;
                    break;

                case EntityState.Deleted:
                    entry.State = EntityState.Modified;
                    entry.Entity.IsDeleted = true;
                    entry.Entity.ModifiedDate = now;
                    entry.Entity.ModifiedBy = userId;
                    KeepOwnedParts(entry);
                    break;
            }
        }
    }

    /// <summary>
    /// A removed row's owned parts (a post's details, kept in its JSON column) were marked deleted
    /// with it. The row stays, so they stay too — deleting them would rewrite keys EF does not allow.
    /// </summary>
    private static void KeepOwnedParts(EntityEntry owner)
    {
        foreach (var navigation in owner.Navigations.Where(n => n.Metadata.TargetEntityType.IsOwned()))
        {
            var parts = navigation switch
            {
                CollectionEntry collection => collection.CurrentValue?.Cast<object>() ?? [],
                ReferenceEntry { CurrentValue: { } part } => [part],
                _ => [],
            };

            foreach (var part in parts)
            {
                var partEntry = owner.Context.Entry(part);
                if (partEntry.State == EntityState.Deleted)
                {
                    partEntry.State = EntityState.Unchanged;
                }
            }
        }
    }
}
