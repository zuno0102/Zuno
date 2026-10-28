using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class WorkerProfileConfiguration : IEntityTypeConfiguration<WorkerProfile>
{
    public void Configure(EntityTypeBuilder<WorkerProfile> builder)
    {
        builder.ToTable("worker_profiles");

        builder.Property(wp => wp.HourlyRate).HasColumnType("numeric(10,2)");
        builder.Property(wp => wp.PhotoUrl).HasMaxLength(500);

        builder.Property(wp => wp.CurrentLatitude).HasColumnType("numeric(9,6)");
        builder.Property(wp => wp.CurrentLongitude).HasColumnType("numeric(9,6)");

        builder.HasIndex(wp => wp.UserId).IsUnique().HasDatabaseName("ux_worker_profiles_user_id");

        builder.HasOne(wp => wp.User)
            .WithOne(u => u.WorkerProfile)
            .HasForeignKey<WorkerProfile>(wp => wp.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
