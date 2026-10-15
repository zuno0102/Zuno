using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessServiceMediaConfiguration : IEntityTypeConfiguration<BusinessServiceMedia>
{
    public void Configure(EntityTypeBuilder<BusinessServiceMedia> builder)
    {
        builder.ToTable("business_service_media", t =>
            t.HasCheckConstraint(
                "ck_business_service_media_owner",
                "num_nonnulls(business_service_id, business_service_variant_id) = 1"));

        builder.Property(m => m.Url).HasMaxLength(500).IsRequired();

        builder.HasIndex(m => m.BusinessServiceId).HasDatabaseName("ix_business_service_media_business_service_id");
        builder.HasIndex(m => m.BusinessServiceVariantId).HasDatabaseName("ix_business_service_media_business_service_variant_id");

        builder.HasOne(m => m.BusinessService)
            .WithMany(s => s.Media)
            .HasForeignKey(m => m.BusinessServiceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(m => m.BusinessServiceVariant)
            .WithMany(v => v.Media)
            .HasForeignKey(m => m.BusinessServiceVariantId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
