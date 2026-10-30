using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Infrastructure.Persistence.Seed;

namespace Zuno.Rent.Infrastructure.Persistence;

public class RentalCategoryConfiguration : IEntityTypeConfiguration<RentalCategory>
{
    public void Configure(EntityTypeBuilder<RentalCategory> builder)
    {
        builder.ToTable("rental_categories");
        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Slug).HasMaxLength(100).IsRequired();
        builder.Property(c => c.IconName).HasMaxLength(50);
        builder.HasIndex(c => c.Slug).IsUnique();
        builder.HasData(RentalCategorySeedData.Categories);
    }
}

public class RentalSubCategoryConfiguration : IEntityTypeConfiguration<RentalSubCategory>
{
    public void Configure(EntityTypeBuilder<RentalSubCategory> builder)
    {
        builder.ToTable("rental_sub_categories");
        builder.Property(s => s.Name).HasMaxLength(100).IsRequired();
        builder.Property(s => s.Slug).HasMaxLength(100).IsRequired();
        builder.HasIndex(s => new { s.RentalCategoryId, s.Slug }).IsUnique();
        builder.HasOne(s => s.RentalCategory)
            .WithMany(c => c.SubCategories)
            .HasForeignKey(s => s.RentalCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasData(RentalCategorySeedData.SubCategories);
    }
}

public class RentalItemConfiguration : IEntityTypeConfiguration<RentalItem>
{
    public void Configure(EntityTypeBuilder<RentalItem> builder)
    {
        builder.ToTable("rental_items", t =>
        {
            // The database refuses what the domain refuses, whoever writes the row.
            t.HasCheckConstraint("ck_rental_items_quantity_owned", "quantity_owned >= 1");
            t.HasCheckConstraint("ck_rental_items_price", "price > 0");
            t.HasCheckConstraint("ck_rental_items_price_type", "price_type IN (1, 2, 3)");
            t.HasCheckConstraint(
                "ck_rental_items_advance",
                "(advance_type = 0 AND advance_amount IS NULL) OR (advance_type IN (1, 2) AND advance_amount > 0)");
        });
        builder.Property(i => i.AdvanceAmount).HasPrecision(12, 2);
        builder.Property(i => i.Name).HasMaxLength(200).IsRequired();
        builder.Property(i => i.Description).HasMaxLength(1000);
        builder.Property(i => i.Price).HasPrecision(12, 2);

        // The business's list: its own items, newest first.
        builder.HasIndex(i => new { i.OwnerUserId, i.CreatedDate });
        builder.HasIndex(i => i.RentalCategoryId);
        builder.HasIndex(i => i.RentalSubCategoryId);

        builder.HasOne(i => i.RentalCategory)
            .WithMany()
            .HasForeignKey(i => i.RentalCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(i => i.RentalSubCategory)
            .WithMany()
            .HasForeignKey(i => i.RentalSubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class RentalItemMediaConfiguration : IEntityTypeConfiguration<RentalItemMedia>
{
    public void Configure(EntityTypeBuilder<RentalItemMedia> builder)
    {
        builder.ToTable("rental_item_media");
        builder.Property(m => m.Url).HasMaxLength(500).IsRequired();
        builder.HasIndex(m => m.RentalItemId);
        builder.HasOne(m => m.RentalItem)
            .WithMany(i => i.Media)
            .HasForeignKey(m => m.RentalItemId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class RentalItemDistrictConfiguration : IEntityTypeConfiguration<RentalItemDistrict>
{
    public void Configure(EntityTypeBuilder<RentalItemDistrict> builder)
    {
        builder.ToTable("rental_item_districts");

        // Unique among live rows only: a district removed (soft-deleted) and chosen again later gets
        // a fresh row next to the old one.
        builder.HasIndex(d => new { d.RentalItemId, d.DistrictId })
            .IsUnique()
            .HasFilter("is_deleted = false");

        // Step 2's customer search reads "items offered in this district".
        builder.HasIndex(d => d.DistrictId);

        builder.HasOne(d => d.RentalItem)
            .WithMany(i => i.Districts)
            .HasForeignKey(d => d.RentalItemId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(d => d.District)
            .WithMany()
            .HasForeignKey(d => d.DistrictId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class RentalItemQuestionConfiguration : IEntityTypeConfiguration<RentalItemQuestion>
{
    public void Configure(EntityTypeBuilder<RentalItemQuestion> builder)
    {
        builder.ToTable("rental_item_questions");
        builder.Property(q => q.Prompt).HasMaxLength(200).IsRequired();

        // An item's questions, read in order with its card.
        builder.HasIndex(q => new { q.RentalItemId, q.SortOrder });
        builder.HasOne(q => q.RentalItem)
            .WithMany(i => i.Questions)
            .HasForeignKey(q => q.RentalItemId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class RentalPriceTypeOptionConfiguration : IEntityTypeConfiguration<RentalPriceTypeOption>
{
    public void Configure(EntityTypeBuilder<RentalPriceTypeOption> builder)
    {
        builder.ToTable("ref_rental_price_types");
        builder.HasKey(p => p.Code);
        builder.Property(p => p.Code).ValueGeneratedNever();
        builder.Property(p => p.Name).HasMaxLength(50).IsRequired();
        builder.Property(p => p.Detail).HasMaxLength(150).IsRequired();
        builder.Property(p => p.UnitSuffix).HasMaxLength(20).IsRequired();
        builder.HasData(RentalPriceTypeSeedData.Options);
    }
}

public class RentalOrderConfiguration : IEntityTypeConfiguration<RentalOrder>
{
    public void Configure(EntityTypeBuilder<RentalOrder> builder)
    {
        builder.ToTable("rental_orders", t =>
        {
            t.HasCheckConstraint("ck_rental_orders_quantity", "quantity >= 1");
            t.HasCheckConstraint("ck_rental_orders_dates", "end_date >= start_date");
            t.HasCheckConstraint("ck_rental_orders_amounts", "amount >= 0 AND advance_due >= 0 AND advance_due <= amount");
            t.HasCheckConstraint("ck_rental_orders_units", "units >= 1");
        });
        builder.Property(o => o.UnitPrice).HasPrecision(12, 2);
        builder.Property(o => o.Amount).HasPrecision(14, 2);
        builder.Property(o => o.AdvanceDue).HasPrecision(14, 2);

        // The lapse job: orders still waiting for their advance, oldest hold first.
        builder.HasIndex(o => new { o.Status, o.HoldUntil });
        builder.Property(o => o.CustomerName).HasMaxLength(200).IsRequired();
        builder.Property(o => o.CustomerPhone).HasMaxLength(20);
        builder.Property(o => o.DeliveryAddress).HasMaxLength(500).IsRequired();

        // Out stock per item (sum by status) and an item's Orders tab.
        builder.HasIndex(o => new { o.RentalItemId, o.Status });
        builder.HasIndex(o => new { o.RentalItemId, o.StartDate });

        // Step 2: a business's and a customer's own orders.
        builder.HasIndex(o => new { o.OwnerUserId, o.StartDate });
        builder.HasIndex(o => o.CustomerUserId);

        builder.HasOne(o => o.RentalItem)
            .WithMany()
            .HasForeignKey(o => o.RentalItemId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(o => o.District)
            .WithMany()
            .HasForeignKey(o => o.DistrictId)
            .OnDelete(DeleteBehavior.Restrict);

        // Add-ons point at the order they extend; the parent lists them.
        builder.HasOne<RentalOrder>()
            .WithMany()
            .HasForeignKey(o => o.ParentOrderId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(o => o.ParentOrderId);
    }
}

public class RentalOrderStatusOptionConfiguration : IEntityTypeConfiguration<RentalOrderStatusOption>
{
    public void Configure(EntityTypeBuilder<RentalOrderStatusOption> builder)
    {
        builder.ToTable("ref_rental_order_statuses");
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();
        builder.HasData(RentalOrderStatusSeedData.Options);
    }
}

public class RentalOrderTransitionConfiguration : IEntityTypeConfiguration<RentalOrderTransition>
{
    public void Configure(EntityTypeBuilder<RentalOrderTransition> builder)
    {
        builder.ToTable("ref_rental_order_transitions");
        builder.HasKey(t => new { t.FromStatus, t.ToStatus });
        builder.Property(t => t.ActionLabel).HasMaxLength(50).IsRequired();
        builder.HasData(RentalOrderStatusSeedData.Transitions);
    }
}

public class RentalOrderEventConfiguration : IEntityTypeConfiguration<RentalOrderEvent>
{
    public void Configure(EntityTypeBuilder<RentalOrderEvent> builder)
    {
        builder.ToTable("rental_order_events", t =>
            t.HasCheckConstraint("ck_rental_order_events_quantity", "quantity >= 0"));

        builder.Property(e => e.Amount).HasPrecision(14, 2);

        // An order's history, read in order.
        builder.HasIndex(e => new { e.RentalOrderId, e.CreatedDate });
        builder.HasOne<RentalOrder>()
            .WithMany()
            .HasForeignKey(e => e.RentalOrderId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class RentalOrderEventKindOptionConfiguration : IEntityTypeConfiguration<RentalOrderEventKindOption>
{
    public void Configure(EntityTypeBuilder<RentalOrderEventKindOption> builder)
    {
        builder.ToTable("ref_rental_order_event_kinds");
        builder.HasKey(k => k.Code);
        builder.Property(k => k.Code).ValueGeneratedNever();
        builder.Property(k => k.Name).HasMaxLength(50).IsRequired();
        builder.HasData(RentalOrderStatusSeedData.EventKinds);
    }
}

public class RentalBusinessConfiguration : IEntityTypeConfiguration<RentalBusiness>
{
    public void Configure(EntityTypeBuilder<RentalBusiness> builder)
    {
        builder.ToTable("rental_businesses");
        builder.HasKey(b => b.OwnerUserId);
        builder.Property(b => b.OwnerUserId).ValueGeneratedNever();
        builder.Property(b => b.Name).HasMaxLength(200).IsRequired();
        builder.Property(b => b.LogoUrl).HasMaxLength(500);
        builder.Property(b => b.UpiId).HasMaxLength(100);
    }
}

public class RentalOrderAnswerConfiguration : IEntityTypeConfiguration<RentalOrderAnswer>
{
    public void Configure(EntityTypeBuilder<RentalOrderAnswer> builder)
    {
        builder.ToTable("rental_order_answers");
        builder.Property(a => a.Prompt).HasMaxLength(200).IsRequired();
        builder.Property(a => a.Answer).HasMaxLength(1000).IsRequired();
        builder.HasIndex(a => a.RentalOrderId);
        builder.HasOne<RentalOrder>()
            .WithMany()
            .HasForeignKey(a => a.RentalOrderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class RentalHomeSectionConfiguration : IEntityTypeConfiguration<RentalHomeSection>
{
    public void Configure(EntityTypeBuilder<RentalHomeSection> builder)
    {
        builder.ToTable("ref_rental_home_sections", t =>
            t.HasCheckConstraint("ck_ref_rental_home_sections_size", "size BETWEEN 1 AND 50"));
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).HasMaxLength(30);
        builder.Property(s => s.Title).HasMaxLength(60).IsRequired();
        builder.HasData(RentalOrderStatusSeedData.HomeSections);
    }
}

public class RentalOrderMessageConfiguration : IEntityTypeConfiguration<RentalOrderMessage>
{
    public void Configure(EntityTypeBuilder<RentalOrderMessage> builder)
    {
        builder.ToTable("rental_order_messages");
        builder.Property(m => m.Body).HasMaxLength(1000).IsRequired();

        // A conversation read in order, and the unread count per order.
        builder.HasIndex(m => new { m.RentalOrderId, m.CreatedDate });
        builder.HasOne(m => m.RentalOrder)
            .WithMany()
            .HasForeignKey(m => m.RentalOrderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class RefStateConfiguration : IEntityTypeConfiguration<RefState>
{
    public void Configure(EntityTypeBuilder<RefState> builder)
    {
        builder.ToTable("ref_states");
        builder.Property(s => s.Name).HasMaxLength(100).IsRequired();
        builder.HasData(LocationSeedData.States);
    }
}

public class RefDistrictConfiguration : IEntityTypeConfiguration<RefDistrict>
{
    public void Configure(EntityTypeBuilder<RefDistrict> builder)
    {
        builder.ToTable("ref_districts");
        builder.Property(d => d.Name).HasMaxLength(100).IsRequired();
        builder.HasIndex(d => d.StateId);
        builder.HasOne(d => d.State)
            .WithMany()
            .HasForeignKey(d => d.StateId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasData(LocationSeedData.Districts);
    }
}

public class RentalOrderPaymentConfiguration : IEntityTypeConfiguration<RentalOrderPayment>
{
    public void Configure(EntityTypeBuilder<RentalOrderPayment> builder)
    {
        builder.ToTable("rental_order_payments", t =>
        {
            t.HasCheckConstraint("ck_rental_order_payments_amount", "amount > 0");
            t.HasCheckConstraint("ck_rental_order_payments_kind", "kind IN (1, 2, 3)");
            t.HasCheckConstraint("ck_rental_order_payments_method", "method IN (1, 2, 3)");
        });
        builder.Property(p => p.Amount).HasPrecision(14, 2);
        builder.Property(p => p.ProviderOrderId).HasMaxLength(100);
        builder.Property(p => p.ProviderPaymentId).HasMaxLength(100);

        // An order's payments, in order; and one gateway payment counted once, ever.
        builder.HasIndex(p => new { p.RentalOrderId, p.CreatedDate });
        builder.HasIndex(p => p.ProviderPaymentId).IsUnique().HasFilter("provider_payment_id IS NOT NULL");
        builder.HasOne<RentalOrder>()
            .WithMany()
            .HasForeignKey(p => p.RentalOrderId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class RentalPaymentCheckoutConfiguration : IEntityTypeConfiguration<RentalPaymentCheckout>
{
    public void Configure(EntityTypeBuilder<RentalPaymentCheckout> builder)
    {
        builder.ToTable("rental_payment_checkouts", t =>
            t.HasCheckConstraint("ck_rental_payment_checkouts_amount", "amount > 0"));
        builder.Property(c => c.Amount).HasPrecision(14, 2);
        builder.Property(c => c.ProviderOrderId).HasMaxLength(100).IsRequired();
        builder.HasIndex(c => c.ProviderOrderId).IsUnique();
        builder.HasIndex(c => c.RentalOrderId);
        builder.HasOne<RentalOrder>()
            .WithMany()
            .HasForeignKey(c => c.RentalOrderId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class RentalAdvanceTypeOptionConfiguration : IEntityTypeConfiguration<RentalAdvanceTypeOption>
{
    public void Configure(EntityTypeBuilder<RentalAdvanceTypeOption> builder)
    {
        builder.ToTable("ref_rental_advance_types");
        builder.HasKey(a => a.Code);
        builder.Property(a => a.Code).ValueGeneratedNever();
        builder.Property(a => a.Name).HasMaxLength(50).IsRequired();
        builder.Property(a => a.Detail).HasMaxLength(120).IsRequired();
        builder.HasData(RentalPaymentSeedData.AdvanceTypes);
    }
}

public class RentalPaymentMethodOptionConfiguration : IEntityTypeConfiguration<RentalPaymentMethodOption>
{
    public void Configure(EntityTypeBuilder<RentalPaymentMethodOption> builder)
    {
        builder.ToTable("ref_rental_payment_methods");
        builder.HasKey(m => m.Code);
        builder.Property(m => m.Code).ValueGeneratedNever();
        builder.Property(m => m.Name).HasMaxLength(50).IsRequired();
        builder.HasData(RentalPaymentSeedData.Methods);
    }
}

public class RentalPaymentStatusOptionConfiguration : IEntityTypeConfiguration<RentalPaymentStatusOption>
{
    public void Configure(EntityTypeBuilder<RentalPaymentStatusOption> builder)
    {
        builder.ToTable("ref_rental_payment_statuses");
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();
        builder.HasData(RentalPaymentSeedData.Statuses);
    }
}
