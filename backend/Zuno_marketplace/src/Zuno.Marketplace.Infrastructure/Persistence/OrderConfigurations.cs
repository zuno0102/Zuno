using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Marketplace.Application.Orders;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.Infrastructure.Persistence;

public class MarketplaceOrderConfiguration : IEntityTypeConfiguration<MarketplaceOrder>
{
    public void Configure(EntityTypeBuilder<MarketplaceOrder> builder)
    {
        builder.ToTable("marketplace_orders", t =>
        {
            // The database refuses what the domain refuses, whoever writes the row.
            t.HasCheckConstraint("ck_marketplace_orders_status", "status BETWEEN 1 AND 8");
            t.HasCheckConstraint("ck_marketplace_orders_payment_method", "payment_method IN (1, 2)");
            t.HasCheckConstraint("ck_marketplace_orders_quantity", "quantity >= 1");
            t.HasCheckConstraint("ck_marketplace_orders_amount", "unit_price > 0 AND amount > 0");
            t.HasCheckConstraint("ck_marketplace_orders_rating", "rating_score IS NULL OR rating_score BETWEEN 1 AND 5");

            // Shipped and later always say how: the courier and its number.
            t.HasCheckConstraint(
                "ck_marketplace_orders_tracking",
                "status NOT IN (4, 5) OR (courier_name IS NOT NULL AND tracking_number IS NOT NULL)");
        });
        builder.Property(o => o.CustomerName).HasMaxLength(200).IsRequired();
        builder.Property(o => o.CustomerPhone).HasMaxLength(MarketplaceOrderLimits.PhoneLength).IsRequired();
        builder.Property(o => o.DeliveryAddress).HasMaxLength(MarketplaceOrderLimits.AddressLength).IsRequired();
        builder.Property(o => o.Pincode).HasMaxLength(MarketplaceOrderLimits.PincodeLength).IsRequired();
        builder.Property(o => o.Title).HasMaxLength(120).IsRequired();
        builder.Property(o => o.VariantName).HasMaxLength(70);
        builder.Property(o => o.UnitPrice).HasPrecision(14, 2);
        builder.Property(o => o.Amount).HasPrecision(14, 2);
        builder.Property(o => o.ProviderOrderId).HasMaxLength(100);
        builder.Property(o => o.ProviderPaymentId).HasMaxLength(100);
        builder.Property(o => o.RefundId).HasMaxLength(100);
        builder.Property(o => o.CourierCode).HasMaxLength(40);
        builder.Property(o => o.CourierName).HasMaxLength(MarketplaceOrderLimits.CourierNameLength);
        builder.Property(o => o.TrackingNumber).HasMaxLength(MarketplaceOrderLimits.TrackingNumberLength);
        builder.Property(o => o.ReceiptUrl).HasMaxLength(500);
        builder.Property(o => o.RatingComment).HasMaxLength(MarketplaceOrderLimits.ReviewLength);
        builder.Ignore(o => o.DueToBusiness);

        // Two steps on one order at once cannot both win silently.
        builder.Property<uint>("xmin").IsRowVersion();

        // The business's list by status, newest first; the customer's own list; the timed job.
        builder.HasIndex(o => new { o.OwnerUserId, o.Status, o.CreatedDate });
        builder.HasIndex(o => new { o.CustomerUserId, o.CreatedDate });
        builder.HasIndex(o => new { o.Status, o.PayBy });
        builder.HasIndex(o => new { o.Status, o.ClosesAt });

        // One payment proves one order, however often it is reported.
        builder.HasIndex(o => o.ProviderPaymentId).IsUnique().HasFilter("provider_payment_id IS NOT NULL");

        builder.HasOne(o => o.Post).WithMany().HasForeignKey(o => o.PostId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(o => o.Events).WithOne().HasForeignKey(e => e.OrderId).OnDelete(DeleteBehavior.Cascade);
    }
}

public class MarketplaceOrderEventConfiguration : IEntityTypeConfiguration<MarketplaceOrderEvent>
{
    public void Configure(EntityTypeBuilder<MarketplaceOrderEvent> builder)
    {
        builder.ToTable("marketplace_order_events", t => t.HasCheckConstraint("ck_marketplace_order_events_actor", "actor IN (1, 2, 3)"));
        builder.Property(e => e.Note).HasMaxLength(200);
        builder.HasIndex(e => new { e.OrderId, e.At });
    }
}

public class MarketplaceOrderStatusOptionConfiguration : IEntityTypeConfiguration<MarketplaceOrderStatusOption>
{
    public void Configure(EntityTypeBuilder<MarketplaceOrderStatusOption> builder)
    {
        builder.ToTable("ref_marketplace_order_statuses");
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();
        builder.HasData(MarketplaceOrderSeedData.Statuses);
    }
}

public class MarketplaceOrderTransitionConfiguration : IEntityTypeConfiguration<MarketplaceOrderTransition>
{
    public void Configure(EntityTypeBuilder<MarketplaceOrderTransition> builder)
    {
        builder.ToTable("ref_marketplace_order_transitions");
        builder.HasKey(t => new { t.FromStatus, t.ToStatus });
        builder.Property(t => t.ActionName).HasMaxLength(50).IsRequired();
        builder.HasData(MarketplaceOrderSeedData.Transitions);
    }
}

public class MarketplaceCourierConfiguration : IEntityTypeConfiguration<MarketplaceCourier>
{
    public void Configure(EntityTypeBuilder<MarketplaceCourier> builder)
    {
        builder.ToTable("ref_marketplace_couriers");
        builder.HasKey(c => c.Code);
        builder.Property(c => c.Code).HasMaxLength(40);
        builder.Property(c => c.Name).HasMaxLength(MarketplaceOrderLimits.CourierNameLength).IsRequired();
        builder.Property(c => c.TrackingUrl).HasMaxLength(300);
        builder.HasData(MarketplaceOrderSeedData.Couriers);
    }
}

public class MarketplacePaymentMethodOptionConfiguration : IEntityTypeConfiguration<MarketplacePaymentMethodOption>
{
    public void Configure(EntityTypeBuilder<MarketplacePaymentMethodOption> builder)
    {
        builder.ToTable("ref_marketplace_payment_methods");
        builder.HasKey(m => m.Code);
        builder.Property(m => m.Code).ValueGeneratedNever();
        builder.Property(m => m.Name).HasMaxLength(50).IsRequired();
        builder.Property(m => m.Detail).HasMaxLength(200).IsRequired();
        builder.HasData(MarketplaceOrderSeedData.PaymentMethods);
    }
}

public class MarketplaceB2BRequestConfiguration : IEntityTypeConfiguration<MarketplaceB2BRequest>
{
    public void Configure(EntityTypeBuilder<MarketplaceB2BRequest> builder)
    {
        builder.ToTable("marketplace_b2b_requests", t =>
        {
            t.HasCheckConstraint("ck_marketplace_b2b_requests_status", "status IN (1, 2, 3)");
            t.HasCheckConstraint("ck_marketplace_b2b_requests_quantity", "quantity >= 1");
        });
        builder.Property(r => r.BuyerName).HasMaxLength(200).IsRequired();
        builder.Property(r => r.BuyerPhone).HasMaxLength(MarketplaceOrderLimits.PhoneLength);
        builder.Property(r => r.Title).HasMaxLength(120).IsRequired();
        builder.Property(r => r.Unit).HasMaxLength(20);
        builder.Property(r => r.UnitPrice).HasPrecision(14, 2);
        builder.Property(r => r.Message).HasMaxLength(MarketplaceOrderLimits.MessageLength);
        builder.Property(r => r.SellerName).HasMaxLength(200);
        builder.Property(r => r.SellerPhone).HasMaxLength(MarketplaceOrderLimits.PhoneLength);
        builder.Property<uint>("xmin").IsRowVersion();

        builder.HasIndex(r => new { r.OwnerUserId, r.Status, r.CreatedDate });
        builder.HasIndex(r => new { r.BuyerUserId, r.CreatedDate });

        // One open request per buyer and lot; a declined or accepted one leaves room to ask again.
        builder.HasIndex(r => new { r.PostId, r.BuyerUserId }).IsUnique().HasFilter("status = 1 AND is_deleted = false");
        builder.HasOne(r => r.Post).WithMany().HasForeignKey(r => r.PostId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class MarketplaceB2BRequestStatusOptionConfiguration : IEntityTypeConfiguration<MarketplaceB2BRequestStatusOption>
{
    public void Configure(EntityTypeBuilder<MarketplaceB2BRequestStatusOption> builder)
    {
        builder.ToTable("ref_marketplace_b2b_request_statuses");
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();
        builder.HasData(MarketplaceOrderSeedData.B2BRequestStatuses);
    }
}
