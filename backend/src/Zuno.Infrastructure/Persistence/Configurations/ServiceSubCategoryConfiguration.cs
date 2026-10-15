using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class ServiceSubCategoryConfiguration : IEntityTypeConfiguration<ServiceSubCategory>
{
    public void Configure(EntityTypeBuilder<ServiceSubCategory> builder)
    {
        builder.ToTable("service_sub_categories");

        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Slug).HasMaxLength(120).IsRequired();

        builder.HasOne(c => c.ServiceCategory)
            .WithMany(c => c.SubCategories)
            .HasForeignKey(c => c.ServiceCategoryId)
            .OnDelete(DeleteBehavior.Cascade);

        // Slugs repeat across categories — "water tank cleaning" belongs under both Plumbing and
        // Cleaning — so uniqueness is per parent rather than global.
        builder.HasIndex(c => new { c.ServiceCategoryId, c.Slug })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_service_sub_categories_category_slug");

        builder.HasData(ServiceSubCategorySeedData.All);
    }
}
