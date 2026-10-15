using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessOwnerProfileConfiguration : IEntityTypeConfiguration<BusinessOwnerProfile>
{
    public void Configure(EntityTypeBuilder<BusinessOwnerProfile> builder)
    {
        builder.ToTable("business_owner_profiles");

        builder.Property(bp => bp.BusinessName).HasMaxLength(200).IsRequired();
        builder.Property(bp => bp.BusinessType).HasMaxLength(100);
        builder.Property(bp => bp.GstNumber).HasMaxLength(15);
        builder.Property(bp => bp.Description).HasMaxLength(1000);
        builder.Property(bp => bp.LogoUrl).HasMaxLength(500);

        builder.HasIndex(bp => bp.UserId).IsUnique().HasDatabaseName("ux_business_owner_profiles_user_id");

        builder.HasOne(bp => bp.User)
            .WithOne(u => u.BusinessOwnerProfile)
            .HasForeignKey<BusinessOwnerProfile>(bp => bp.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(bp => bp.BusinessAddress)
            .WithMany()
            .HasForeignKey(bp => bp.BusinessAddressId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
