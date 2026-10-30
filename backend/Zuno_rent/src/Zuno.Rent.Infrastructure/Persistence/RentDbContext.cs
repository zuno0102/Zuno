using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Common;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Infrastructure.Persistence;

/// <summary>The Rent database: its own, apart from the Service database.</summary>
public class RentDbContext(DbContextOptions<RentDbContext> options) : DbContext(options), IRentDbContext
{
    public DbSet<RentalItem> RentalItems => Set<RentalItem>();

    public DbSet<RentalItemMedia> RentalItemMedia => Set<RentalItemMedia>();

    public DbSet<RentalItemDistrict> RentalItemDistricts => Set<RentalItemDistrict>();

    public DbSet<RentalItemQuestion> RentalItemQuestions => Set<RentalItemQuestion>();

    public DbSet<RentalPriceTypeOption> RentalPriceTypes => Set<RentalPriceTypeOption>();

    public DbSet<RentalOrder> RentalOrders => Set<RentalOrder>();

    public DbSet<RentalOrderStatusOption> RentalOrderStatuses => Set<RentalOrderStatusOption>();

    public DbSet<RentalOrderTransition> RentalOrderTransitions => Set<RentalOrderTransition>();

    public DbSet<RentalOrderMessage> RentalOrderMessages => Set<RentalOrderMessage>();

    public DbSet<RentalOrderEvent> RentalOrderEvents => Set<RentalOrderEvent>();

    public DbSet<RentalOrderEventKindOption> RentalOrderEventKinds => Set<RentalOrderEventKindOption>();

    public DbSet<RentalBusiness> RentalBusinesses => Set<RentalBusiness>();

    public DbSet<RentalOrderAnswer> RentalOrderAnswers => Set<RentalOrderAnswer>();

    public DbSet<RentalHomeSection> RentalHomeSections => Set<RentalHomeSection>();

    public DbSet<RentalOrderPayment> RentalOrderPayments => Set<RentalOrderPayment>();

    public DbSet<RentalPaymentCheckout> RentalPaymentCheckouts => Set<RentalPaymentCheckout>();

    public DbSet<RentalAdvanceTypeOption> RentalAdvanceTypes => Set<RentalAdvanceTypeOption>();

    public DbSet<RentalPaymentMethodOption> RentalPaymentMethods => Set<RentalPaymentMethodOption>();

    public DbSet<RentalPaymentStatusOption> RentalPaymentStatuses => Set<RentalPaymentStatusOption>();

    public DbSet<RentalCategory> RentalCategories => Set<RentalCategory>();

    public DbSet<RentalSubCategory> RentalSubCategories => Set<RentalSubCategory>();

    public DbSet<RefState> States => Set<RefState>();

    public DbSet<RefDistrict> Districts => Set<RefDistrict>();

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Order history only grows: a step once written is never changed or removed.
        if (ChangeTracker.Entries<RentalOrderEvent>().Any(e => e.State is EntityState.Modified or EntityState.Deleted))
        {
            throw new InvalidOperationException("Rent order history cannot be changed or removed.");
        }

        // Nor the money record: a payment is corrected by another payment (a refund), never an edit.
        if (ChangeTracker.Entries<RentalOrderPayment>().Any(e => e.State is EntityState.Modified or EntityState.Deleted))
        {
            throw new InvalidOperationException("Rent order payments cannot be changed or removed.");
        }

        return base.SaveChangesAsync(cancellationToken);
    }

    public async Task<T> WithItemLockAsync<T>(Guid rentalItemId, Func<Task<T>> work, CancellationToken cancellationToken)
    {
        // The in-memory test store has no transactions or row locks; there the work just runs.
        if (!Database.IsRelational())
        {
            return await work();
        }

        await using var transaction = await Database.BeginTransactionAsync(cancellationToken);

        // FOR UPDATE holds the item's row until commit: a second booking for the same item waits
        // here, then counts the first one's pieces.
        await Database.ExecuteSqlInterpolatedAsync(
            $"SELECT id FROM rental_items WHERE id = {rentalItemId} FOR UPDATE",
            cancellationToken);

        var result = await work();
        await transaction.CommitAsync(cancellationToken);
        return result;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(RentDbContext).Assembly);

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
}
