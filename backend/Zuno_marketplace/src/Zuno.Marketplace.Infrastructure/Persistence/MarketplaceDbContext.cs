using System.Linq.Expressions;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Domain.Common;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Infrastructure.Persistence;

/// <summary>The Marketplace database: its own, apart from the Service and Rent databases.</summary>
public class MarketplaceDbContext(DbContextOptions<MarketplaceDbContext> options) : DbContext(options), IMarketplaceDbContext
{
    public DbSet<MarketplaceCategory> Categories => Set<MarketplaceCategory>();

    public DbSet<MarketplaceSubCategory> SubCategories => Set<MarketplaceSubCategory>();

    public DbSet<MarketplaceCategoryField> CategoryFields => Set<MarketplaceCategoryField>();

    public DbSet<MarketplacePost> Posts => Set<MarketplacePost>();

    public DbSet<MarketplacePostMedia> PostMedia => Set<MarketplacePostMedia>();

    public DbSet<MarketplaceBusiness> Businesses => Set<MarketplaceBusiness>();

    public DbSet<MarketplacePlan> Plans => Set<MarketplacePlan>();

    public DbSet<MarketplaceBusinessPlan> BusinessPlans => Set<MarketplaceBusinessPlan>();

    public DbSet<MarketplaceTradeModeOption> TradeModes => Set<MarketplaceTradeModeOption>();

    public DbSet<MarketplaceItemConditionOption> ItemConditions => Set<MarketplaceItemConditionOption>();

    public DbSet<MarketplacePostKindOption> PostKinds => Set<MarketplacePostKindOption>();

    public DbSet<MarketplacePostStatusOption> PostStatuses => Set<MarketplacePostStatusOption>();

    public DbSet<MarketplacePostTransition> PostTransitions => Set<MarketplacePostTransition>();

    public DbSet<RefState> States => Set<RefState>();

    public DbSet<RefDistrict> Districts => Set<RefDistrict>();

    public async Task<T> WithOwnerLockAsync<T>(Guid ownerUserId, Func<Task<T>> work, CancellationToken cancellationToken)
    {
        // The in-memory test store has no transactions or locks; there the work just runs.
        if (!Database.IsRelational())
        {
            return await work();
        }

        await using var transaction = await Database.BeginTransactionAsync(cancellationToken);

        // A lock on the business itself, held until commit: a second save by the same business
        // waits here, then counts the first one's post. No row is needed, so a first post locks too.
        await Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock({LockKey(ownerUserId)})", cancellationToken);

        var result = await work();
        await transaction.CommitAsync(cancellationToken);
        return result;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(MarketplaceDbContext).Assembly);

        // Deleted rows stay in the table, marked, and are hidden from every read.
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            if (typeof(IAuditableEntity).IsAssignableFrom(entityType.ClrType))
            {
                var parameter = Expression.Parameter(entityType.ClrType, "entity");
                var isDeleted = Expression.Property(parameter, nameof(IAuditableEntity.IsDeleted));
                modelBuilder.Entity(entityType.ClrType).HasQueryFilter(
                    Expression.Lambda(Expression.Equal(isDeleted, Expression.Constant(false)), parameter));
            }
        }

        base.OnModelCreating(modelBuilder);
    }

    /// <summary>A stable 64-bit key for the owner, the same in every instance.</summary>
    internal static long LockKey(Guid ownerUserId) => BitConverter.ToInt64(SHA256.HashData(ownerUserId.ToByteArray()), 0);
}
