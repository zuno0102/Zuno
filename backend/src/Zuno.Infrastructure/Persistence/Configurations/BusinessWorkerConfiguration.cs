using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BusinessWorkerConfiguration : IEntityTypeConfiguration<BusinessWorker>
{
    public void Configure(EntityTypeBuilder<BusinessWorker> builder)
    {
        builder.ToTable("business_workers");

        builder.HasIndex(w => w.BusinessOwnerProfileId).HasDatabaseName("ix_business_workers_business_owner_profile_id");
        builder.HasIndex(w => w.WorkerProfileId).HasDatabaseName("ix_business_workers_worker_profile_id");

        builder.HasIndex(w => new { w.BusinessOwnerProfileId, w.WorkerProfileId })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_business_workers_business_worker");

        builder.HasOne(w => w.BusinessOwnerProfile)
            .WithMany(bp => bp.Workers)
            .HasForeignKey(w => w.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(w => w.WorkerProfile)
            .WithMany(wp => wp.BusinessAssignments)
            .HasForeignKey(w => w.WorkerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
