using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class AdminProfileConfiguration : IEntityTypeConfiguration<AdminProfile>
{
    public void Configure(EntityTypeBuilder<AdminProfile> builder)
    {
        builder.ToTable("admin_profiles");

        builder.HasIndex(ap => ap.UserId).IsUnique().HasDatabaseName("ux_admin_profiles_user_id");

        builder.HasOne(ap => ap.User)
            .WithOne(u => u.AdminProfile)
            .HasForeignKey<AdminProfile>(ap => ap.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
