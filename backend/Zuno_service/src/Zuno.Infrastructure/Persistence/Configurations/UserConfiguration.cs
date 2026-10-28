using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users", t => t.HasCheckConstraint(
            "ck_users_email_or_phone_required",
            "email IS NOT NULL OR phone_number IS NOT NULL"));

        builder.Property(u => u.Email).HasMaxLength(256);
        builder.Property(u => u.PhoneNumber).HasMaxLength(15);
        builder.Property(u => u.PasswordHash).IsRequired();
        builder.Property(u => u.FirstName).HasMaxLength(100).IsRequired();
        builder.Property(u => u.LastName).HasMaxLength(100).IsRequired();
        builder.Property(u => u.ProfileImageUrl).HasMaxLength(500);

        builder.HasIndex(u => u.Email)
            .IsUnique()
            .HasFilter("is_deleted = false AND email IS NOT NULL")
            .HasDatabaseName("ux_users_email");

        builder.HasIndex(u => u.PhoneNumber)
            .IsUnique()
            .HasFilter("is_deleted = false AND phone_number IS NOT NULL")
            .HasDatabaseName("ux_users_phone_number");

        builder.HasIndex(u => u.RoleId).HasDatabaseName("ix_users_role_id");

        builder.HasOne(u => u.Role)
            .WithMany(r => r.Users)
            .HasForeignKey(u => u.RoleId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
