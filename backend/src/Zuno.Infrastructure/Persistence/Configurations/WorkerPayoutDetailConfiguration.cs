using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class WorkerPayoutDetailConfiguration : IEntityTypeConfiguration<WorkerPayoutDetail>
{
    public void Configure(EntityTypeBuilder<WorkerPayoutDetail> builder)
    {
        builder.ToTable("worker_payout_details");

        builder.Property(d => d.UpiVpa).HasMaxLength(100);
        builder.Property(d => d.AccountNumber).HasMaxLength(34);
        builder.Property(d => d.IfscCode).HasMaxLength(11);
        builder.Property(d => d.AccountHolderName).HasMaxLength(200);
        builder.Property(d => d.ProviderFundAccountId).HasMaxLength(100);

        // One destination per worker: paying to two places would make "was this settled?" ambiguous.
        builder.HasIndex(d => d.WorkerProfileId)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_worker_payout_details_worker_profile_id");

        builder.HasOne(d => d.WorkerProfile)
            .WithOne(wp => wp.PayoutDetail)
            .HasForeignKey<WorkerPayoutDetail>(d => d.WorkerProfileId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
