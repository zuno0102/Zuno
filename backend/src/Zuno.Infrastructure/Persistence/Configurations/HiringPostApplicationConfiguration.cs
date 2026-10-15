using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class HiringPostApplicationConfiguration : IEntityTypeConfiguration<HiringPostApplication>
{
    public void Configure(EntityTypeBuilder<HiringPostApplication> builder)
    {
        builder.ToTable("hiring_post_applications");

        builder.HasIndex(a => a.HiringPostId).HasDatabaseName("ix_hiring_post_applications_hiring_post_id");
        builder.HasIndex(a => a.WorkerProfileId).HasDatabaseName("ix_hiring_post_applications_worker_profile_id");

        builder.Property(a => a.AgreedSalaryAmount).HasPrecision(10, 2);

        builder.HasOne(a => a.HiringPost)
            .WithMany(p => p.Applications)
            .HasForeignKey(a => a.HiringPostId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(a => a.WorkerProfile)
            .WithMany()
            .HasForeignKey(a => a.WorkerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
