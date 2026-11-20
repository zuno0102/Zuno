using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class SubscriptionPlanConfiguration : IEntityTypeConfiguration<SubscriptionPlan>
{
    public void Configure(EntityTypeBuilder<SubscriptionPlan> builder)
    {
        builder.ToTable("subscription_plans", t =>
        {
            t.HasCheckConstraint("ck_subscription_plans_price", "price >= 0");
            t.HasCheckConstraint("ck_subscription_plans_duration_days", "duration_days IS NULL OR duration_days > 0");
            t.HasCheckConstraint("ck_subscription_plans_max_live_listings", "max_live_listings IS NULL OR max_live_listings >= 0");
        });
        builder.Property(p => p.Code).HasMaxLength(40).IsRequired();
        builder.Property(p => p.Name).HasMaxLength(60).IsRequired();
        builder.Property(p => p.Price).HasPrecision(10, 2);
        builder.HasIndex(p => p.Code).IsUnique().HasDatabaseName("ux_subscription_plans_code");

        // Exactly one Basic plan.
        builder.HasIndex(p => p.IsDefault).IsUnique().HasFilter("is_default = true")
            .HasDatabaseName("ux_subscription_plans_default");
        builder.HasData(BusinessPlanSeedData.Plans);
    }
}

public class BusinessSubscriptionConfiguration : IEntityTypeConfiguration<BusinessSubscription>
{
    public void Configure(EntityTypeBuilder<BusinessSubscription> builder)
    {
        builder.ToTable("business_subscriptions", t =>
        {
            t.HasCheckConstraint("ck_business_subscriptions_amount", "amount >= 0");
            t.HasCheckConstraint("ck_business_subscriptions_state", "state BETWEEN 1 AND 3");
        });
        builder.Property(s => s.PlanName).HasMaxLength(60).IsRequired();
        builder.Property(s => s.Amount).HasPrecision(10, 2);
        builder.Property(s => s.PendingOrderId).HasMaxLength(100);
        builder.Property(s => s.PaymentId).HasMaxLength(100);
        builder.Ignore(s => s.PaymentKey);

        // The business's plans, newest first; and the hourly look for plans that have just ended.
        builder.HasIndex(s => new { s.OwnerUserId, s.State, s.EndsAt }).HasDatabaseName("ix_business_subscriptions_owner_state_ends");
        builder.HasIndex(s => new { s.State, s.EndsAt }).HasDatabaseName("ix_business_subscriptions_state_ends");

        // One payment can activate one purchase only.
        builder.HasIndex(s => s.PaymentId).IsUnique().HasFilter("payment_id IS NOT NULL")
            .HasDatabaseName("ux_business_subscriptions_payment_id");
        builder.HasOne(s => s.Plan).WithMany().HasForeignKey(s => s.PlanId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class PlanPausedListingConfiguration : IEntityTypeConfiguration<PlanPausedListing>
{
    public void Configure(EntityTypeBuilder<PlanPausedListing> builder)
    {
        builder.ToTable("plan_paused_listings");
        builder.HasIndex(p => new { p.OwnerUserId, p.Area, p.ListingId }).IsUnique()
            .HasDatabaseName("ux_plan_paused_listings_owner_area_listing");
    }
}
