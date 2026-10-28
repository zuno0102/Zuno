using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class ServiceCategoryConfiguration : IEntityTypeConfiguration<ServiceCategory>
{
    public void Configure(EntityTypeBuilder<ServiceCategory> builder)
    {
        builder.ToTable("service_categories");

        builder.Property(c => c.Name).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Slug).HasMaxLength(120).IsRequired();
        builder.Property(c => c.Description).HasMaxLength(500);
        builder.Property(c => c.IconUrl).HasMaxLength(500);
        // A short key, not a file path: the client looks it up in the icons it ships with.
        builder.Property(c => c.IconName).HasMaxLength(50);

        builder.HasIndex(c => c.Slug)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_service_categories_slug");

        builder.HasData(ServiceCategorySeedData.All);
    }
}
