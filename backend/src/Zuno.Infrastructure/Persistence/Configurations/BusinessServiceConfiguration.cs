using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessServiceConfiguration : IEntityTypeConfiguration<BusinessService>
{
    public void Configure(EntityTypeBuilder<BusinessService> builder)
    {
        builder.ToTable("business_services");

        builder.Property(s => s.Name).HasMaxLength(200).IsRequired();
        builder.Property(s => s.ItemName).HasMaxLength(200);
        builder.Property(s => s.Description).HasMaxLength(1000);
        builder.Property(s => s.Price).HasPrecision(10, 2);

        builder.HasIndex(s => s.BusinessOwnerProfileId).HasDatabaseName("ix_business_services_business_owner_profile_id");
        builder.HasIndex(s => s.ServiceCategoryId).HasDatabaseName("ix_business_services_service_category_id");

        builder.HasOne(s => s.BusinessOwnerProfile)
            .WithMany(bp => bp.Services)
            .HasForeignKey(s => s.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(s => s.ServiceCategory)
            .WithMany(c => c.BusinessServices)
            .HasForeignKey(s => s.ServiceCategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        // No inverse collection: nothing ever asks a sub-category which services sit under it,
        // and a navigation nobody reads is a join waiting to be loaded by accident.
        builder.HasOne(s => s.ServiceSubCategory)
            .WithMany()
            .HasForeignKey(s => s.ServiceSubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
