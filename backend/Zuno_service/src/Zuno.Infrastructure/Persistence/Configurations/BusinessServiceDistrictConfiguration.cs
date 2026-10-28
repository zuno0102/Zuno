using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessServiceDistrictConfiguration : IEntityTypeConfiguration<BusinessServiceDistrict>
{
    public void Configure(EntityTypeBuilder<BusinessServiceDistrict> builder)
    {
        builder.ToTable("business_service_districts");

        builder.HasIndex(t => t.BusinessServiceId).HasDatabaseName("ix_business_service_districts_business_service_id");
        builder.HasIndex(t => t.DistrictId).HasDatabaseName("ix_business_service_districts_district_id");

        builder.HasOne(t => t.BusinessService)
            .WithMany(s => s.TargetDistricts)
            .HasForeignKey(t => t.BusinessServiceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(t => t.District)
            .WithMany()
            .HasForeignKey(t => t.DistrictId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
