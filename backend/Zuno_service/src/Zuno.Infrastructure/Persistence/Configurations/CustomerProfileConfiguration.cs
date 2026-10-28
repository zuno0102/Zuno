using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class CustomerProfileConfiguration : IEntityTypeConfiguration<CustomerProfile>
{
    public void Configure(EntityTypeBuilder<CustomerProfile> builder)
    {
        builder.ToTable("customer_profiles");

        builder.Property(cp => cp.PreferredLanguage).HasMaxLength(10).IsRequired();

        builder.HasIndex(cp => cp.UserId).IsUnique().HasDatabaseName("ux_customer_profiles_user_id");

        builder.HasOne(cp => cp.User)
            .WithOne(u => u.CustomerProfile)
            .HasForeignKey<CustomerProfile>(cp => cp.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(cp => cp.DefaultAddress)
            .WithMany()
            .HasForeignKey(cp => cp.DefaultAddressId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
