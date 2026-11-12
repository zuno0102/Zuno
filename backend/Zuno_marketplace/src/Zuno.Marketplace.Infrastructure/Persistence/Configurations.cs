using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.Infrastructure.Persistence;

public class MarketplaceCategoryConfiguration : IEntityTypeConfiguration<MarketplaceCategory>
{
    public void Configure(EntityTypeBuilder<MarketplaceCategory> builder)
    {
        builder.ToTable("marketplace_categories", t =>
        {
            t.HasCheckConstraint("ck_marketplace_categories_kind", "kind IN (1, 2, 3)");
            t.HasCheckConstraint("ck_marketplace_categories_trade_mode", "trade_mode IN (1, 2, 3)");
        });
        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.ShortName).HasMaxLength(20);
        builder.Property(c => c.Description).HasMaxLength(200);
        builder.Property(c => c.Slug).HasMaxLength(100).IsRequired();
        builder.Property(c => c.IconName).HasMaxLength(50);
        builder.HasIndex(c => c.Slug).IsUnique().HasFilter("is_deleted = false");
        builder.HasData(MarketplaceCatalogSeedData.Categories);
    }
}

public class MarketplaceSubCategoryConfiguration : IEntityTypeConfiguration<MarketplaceSubCategory>
{
    public void Configure(EntityTypeBuilder<MarketplaceSubCategory> builder)
    {
        builder.ToTable("marketplace_sub_categories");
        builder.Property(s => s.Name).HasMaxLength(100).IsRequired();
        builder.Property(s => s.Slug).HasMaxLength(100).IsRequired();
        builder.Property(s => s.IconName).HasMaxLength(50);
        builder.HasIndex(s => new { s.CategoryId, s.Slug }).IsUnique().HasFilter("is_deleted = false");
        builder.HasOne(s => s.Category)
            .WithMany(c => c.SubCategories)
            .HasForeignKey(s => s.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasData(MarketplaceCatalogSeedData.SubCategories);
    }
}

public class MarketplaceCategoryFieldConfiguration : IEntityTypeConfiguration<MarketplaceCategoryField>
{
    public void Configure(EntityTypeBuilder<MarketplaceCategoryField> builder)
    {
        builder.ToTable("marketplace_category_fields", t => t.HasCheckConstraint("ck_marketplace_category_fields_type", "field_type IN (1, 2, 3)"));
        builder.Property(f => f.Key).HasMaxLength(60).IsRequired();
        builder.Property(f => f.Label).HasMaxLength(60).IsRequired();
        builder.Property(f => f.Unit).HasMaxLength(20);

        builder.Property(f => f.Options).Metadata.SetValueComparer(ChoiceListComparer.Instance);
        // One key per place it is asked: the whole category (no sub-category) counts as one place.
        builder.HasIndex(f => new { f.CategoryId, f.SubCategoryId, f.Key })
            .IsUnique()
            .AreNullsDistinct(false)
            .HasFilter("is_deleted = false");
        builder.HasOne(f => f.Category)
            .WithMany(c => c.Fields)
            .HasForeignKey(f => f.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(f => f.SubCategory)
            .WithMany()
            .HasForeignKey(f => f.SubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasData(MarketplaceCatalogSeedData.Fields);
    }
}

public class MarketplacePostConfiguration : IEntityTypeConfiguration<MarketplacePost>
{
    public void Configure(EntityTypeBuilder<MarketplacePost> builder)
    {
        builder.ToTable("marketplace_posts", t =>
        {
            // The database refuses what the domain refuses, whoever writes the row.
            t.HasCheckConstraint("ck_marketplace_posts_kind", "kind IN (1, 2, 3)");
            // 4 (Expired) is never stored: it is an Active post whose end has passed.
            t.HasCheckConstraint("ck_marketplace_posts_status", "status IN (1, 2, 3, 5)");
            t.HasCheckConstraint("ck_marketplace_posts_trade_type", "trade_type IN (1, 2)");
            t.HasCheckConstraint("ck_marketplace_posts_condition", "condition IS NULL OR condition IN (1, 2)");
            t.HasCheckConstraint("ck_marketplace_posts_price", "price IS NULL OR price > 0");

            // 0 is a new item out of stock; every other quantity is at least 1.
            t.HasCheckConstraint("ck_marketplace_posts_quantity", "quantity IS NULL OR quantity >= 1 OR (quantity = 0 AND condition = 1)");
            t.HasCheckConstraint("ck_marketplace_posts_pack_quantity", "pack_quantity IS NULL OR pack_quantity >= 1");
            t.HasCheckConstraint("ck_marketplace_posts_window", "ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at");
            t.HasCheckConstraint("ck_marketplace_posts_location", "(latitude IS NULL) = (longitude IS NULL)");

            // All of India, or a state (whole, or some of its districts).
            t.HasCheckConstraint("ck_marketplace_posts_ships_to", "delivers_everywhere OR delivery_state_id IS NOT NULL");
        });
        builder.Property(p => p.Title).HasMaxLength(120).IsRequired();
        builder.Property(p => p.Description).HasMaxLength(2000);
        builder.Property(p => p.Price).HasPrecision(14, 2);
        builder.Property(p => p.OriginalPrice).HasPrecision(14, 2);
        builder.Property(p => p.PriceUnit).HasMaxLength(20);
        builder.Property(p => p.ContactPhone).HasMaxLength(20);
        builder.Property(p => p.Area).HasMaxLength(120);

        // A few details read and written with the post, never queried on their own: one JSON column.
        builder.OwnsMany(p => p.Attributes, attributes =>
        {
            attributes.ToJson("attributes");
            attributes.Property(a => a.Key).HasMaxLength(60);
            attributes.Property(a => a.Value).HasMaxLength(200);
        });
        builder.OwnsMany(p => p.CustomDetails, details =>
        {
            details.ToJson("custom_details");
            details.Property(a => a.Key).HasMaxLength(60);
            details.Property(a => a.Value).HasMaxLength(200);
        });

        // Postgres's own row version (xmin — no column is added): two edits of one post at once
        // cannot both win silently.
        builder.Property<uint>("xmin").IsRowVersion();

        // The business's list (newest first) and the plan count (live posts of one owner).
        builder.HasIndex(p => new { p.OwnerUserId, p.CreatedDate });
        builder.HasIndex(p => new { p.OwnerUserId, p.Status, p.EndsAt });

        // The customer screens: live posts by kind, district and end time.
        builder.HasIndex(p => new { p.Kind, p.Status, p.DistrictId, p.EndsAt });
        builder.HasIndex(p => new { p.CategoryId, p.SubCategoryId });

        builder.HasOne(p => p.Category).WithMany().HasForeignKey(p => p.CategoryId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(p => p.SubCategory).WithMany().HasForeignKey(p => p.SubCategoryId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(p => p.District).WithMany().HasForeignKey(p => p.DistrictId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<RefState>().WithMany().HasForeignKey(p => p.DeliveryStateId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class MarketplacePostVariantConfiguration : IEntityTypeConfiguration<MarketplacePostVariant>
{
    public void Configure(EntityTypeBuilder<MarketplacePostVariant> builder)
    {
        builder.ToTable("marketplace_post_variants", t =>
        {
            t.HasCheckConstraint("ck_marketplace_post_variants_stock", "stock >= 0");
            t.HasCheckConstraint("ck_marketplace_post_variants_price", "price IS NULL OR price > 0");
            t.HasCheckConstraint("ck_marketplace_post_variants_named", "colour IS NOT NULL OR size IS NOT NULL");
        });
        builder.Property(v => v.Colour).HasMaxLength(40);
        builder.OwnsMany(v => v.CustomDetails, details =>
        {
            details.ToJson("custom_details");
            details.Property(a => a.Key).HasMaxLength(60);
            details.Property(a => a.Value).HasMaxLength(200);
        });
        builder.Property(v => v.Size).HasMaxLength(20);
        builder.Property(v => v.Price).HasPrecision(14, 2);
        builder.Ignore(v => v.Name);

        // One row per colour and size of a post; a removed one (soft-deleted) frees its name.
        builder.HasIndex(v => new { v.PostId, v.Colour, v.Size })
            .IsUnique()
            .AreNullsDistinct(false)
            .HasFilter("is_deleted = false");
        builder.HasOne(v => v.Post)
            .WithMany(p => p.Variants)
            .HasForeignKey(v => v.PostId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class MarketplacePostMediaConfiguration : IEntityTypeConfiguration<MarketplacePostMedia>
{
    public void Configure(EntityTypeBuilder<MarketplacePostMedia> builder)
    {
        builder.ToTable("marketplace_post_media");
        builder.Property(m => m.Url).HasMaxLength(500).IsRequired();
        builder.HasIndex(m => m.PostId);
        builder.HasOne(m => m.Post)
            .WithMany(p => p.Media)
            .HasForeignKey(m => m.PostId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class MarketplaceBusinessConfiguration : IEntityTypeConfiguration<MarketplaceBusiness>
{
    public void Configure(EntityTypeBuilder<MarketplaceBusiness> builder)
    {
        builder.ToTable("marketplace_businesses");
        builder.HasKey(b => b.OwnerUserId);
        builder.Property(b => b.OwnerUserId).ValueGeneratedNever();
        builder.Property(b => b.Name).HasMaxLength(200).IsRequired();
        builder.Property(b => b.LogoUrl).HasMaxLength(500);
    }
}

public class MarketplacePlanConfiguration : IEntityTypeConfiguration<MarketplacePlan>
{
    public void Configure(EntityTypeBuilder<MarketplacePlan> builder)
    {
        builder.ToTable("marketplace_plans", t =>
        {
            t.HasCheckConstraint("ck_marketplace_plans_price", "price >= 0");
            t.HasCheckConstraint("ck_marketplace_plans_max_active_posts", "max_active_posts >= 0");
            t.HasCheckConstraint("ck_marketplace_plans_duration", "duration_days IS NULL OR duration_days >= 1");
        });
        builder.Property(p => p.Code).HasMaxLength(30).IsRequired();
        builder.Property(p => p.Name).HasMaxLength(60).IsRequired();
        builder.Property(p => p.Price).HasPrecision(12, 2);
        builder.HasIndex(p => p.Code).IsUnique().HasFilter("is_deleted = false");

        // Exactly one plan everyone falls back to.
        builder.HasIndex(p => p.IsDefault).IsUnique().HasFilter("is_default = true AND is_deleted = false");
        builder.HasData(MarketplaceCatalogSeedData.Plans);
    }
}

public class MarketplaceBusinessPlanConfiguration : IEntityTypeConfiguration<MarketplaceBusinessPlan>
{
    public void Configure(EntityTypeBuilder<MarketplaceBusinessPlan> builder)
    {
        builder.ToTable("marketplace_business_plans", t =>
            t.HasCheckConstraint("ck_marketplace_business_plans_window", "ends_at IS NULL OR ends_at > starts_at"));
        builder.HasIndex(b => new { b.OwnerUserId, b.StartsAt });
        builder.HasOne(b => b.Plan).WithMany().HasForeignKey(b => b.PlanId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class MarketplaceTradeModeOptionConfiguration : IEntityTypeConfiguration<MarketplaceTradeModeOption>
{
    public void Configure(EntityTypeBuilder<MarketplaceTradeModeOption> builder)
    {
        builder.ToTable("ref_marketplace_trade_modes");
        builder.HasKey(t => t.Code);
        builder.Property(t => t.Code).ValueGeneratedNever();
        builder.Property(t => t.Name).HasMaxLength(50).IsRequired();
        builder.Property(t => t.Detail).HasMaxLength(150).IsRequired();
        builder.HasData(MarketplaceCatalogSeedData.TradeModes);
    }
}

public class MarketplacePostKindOptionConfiguration : IEntityTypeConfiguration<MarketplacePostKindOption>
{
    public void Configure(EntityTypeBuilder<MarketplacePostKindOption> builder)
    {
        builder.ToTable("ref_marketplace_post_kinds");
        builder.HasKey(k => k.Code);
        builder.Property(k => k.Code).ValueGeneratedNever();
        builder.Property(k => k.Name).HasMaxLength(50).IsRequired();
        builder.HasData(MarketplaceCatalogSeedData.Kinds);
    }
}

public class MarketplacePostStatusOptionConfiguration : IEntityTypeConfiguration<MarketplacePostStatusOption>
{
    public void Configure(EntityTypeBuilder<MarketplacePostStatusOption> builder)
    {
        builder.ToTable("ref_marketplace_post_statuses");
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(50).IsRequired();
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();
        builder.HasData(MarketplaceCatalogSeedData.Statuses);
    }
}

public class MarketplacePostTransitionConfiguration : IEntityTypeConfiguration<MarketplacePostTransition>
{
    public void Configure(EntityTypeBuilder<MarketplacePostTransition> builder)
    {
        builder.ToTable("ref_marketplace_post_transitions", t =>
            t.HasCheckConstraint("ck_ref_marketplace_post_transitions_condition", "condition IS NULL OR condition IN (1, 2)"));
        builder.HasKey(t => new { t.FromStatus, t.ToStatus });
        builder.Property(t => t.ActionName).HasMaxLength(50).IsRequired();
        builder.HasData(MarketplaceCatalogSeedData.Transitions);
    }
}

public class MarketplaceItemConditionOptionConfiguration : IEntityTypeConfiguration<MarketplaceItemConditionOption>
{
    public void Configure(EntityTypeBuilder<MarketplaceItemConditionOption> builder)
    {
        builder.ToTable("ref_marketplace_item_conditions");
        builder.HasKey(c => c.Code);
        builder.Property(c => c.Code).ValueGeneratedNever();
        builder.Property(c => c.Name).HasMaxLength(50).IsRequired();
        builder.Property(c => c.Detail).HasMaxLength(150).IsRequired();
        builder.HasData(MarketplaceCatalogSeedData.ItemConditions);
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

/// <summary>
/// Compares a list of choices by its items, not the list object, so seeded rows read the same on
/// every build and a migration is made only when a choice really changes.
/// </summary>
internal static class ChoiceListComparer
{
    public static readonly ValueComparer<List<string>> Instance = new(
        (a, b) => a == b || (a != null && b != null && a.SequenceEqual(b)),
        list => list.Aggregate(0, (hash, item) => HashCode.Combine(hash, item.GetHashCode(StringComparison.Ordinal))),
        list => list.ToList());
}
