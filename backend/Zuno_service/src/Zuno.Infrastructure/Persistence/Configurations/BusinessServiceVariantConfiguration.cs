using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessServiceVariantConfiguration : IEntityTypeConfiguration<BusinessServiceVariant>
{
    public void Configure(EntityTypeBuilder<BusinessServiceVariant> builder)
    {
        builder.ToTable("business_service_variants");

        builder.Property(v => v.Name).HasMaxLength(200).IsRequired();
        builder.Property(v => v.Description).HasMaxLength(1000);
        builder.Property(v => v.Price).HasPrecision(10, 2);

        builder.HasIndex(v => v.BusinessServiceId).HasDatabaseName("ix_business_service_variants_business_service_id");

        builder.HasOne(v => v.BusinessService)
            .WithMany(s => s.Variants)
            .HasForeignKey(v => v.BusinessServiceId)
            .OnDelete(DeleteBehavior.Cascade);

        // Restrict, not Cascade: retiring a sub-category from the catalog must never delete the
        // items businesses have priced under it.
        builder.HasOne(v => v.ServiceSubCategory)
            .WithMany()
            .HasForeignKey(v => v.ServiceSubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
