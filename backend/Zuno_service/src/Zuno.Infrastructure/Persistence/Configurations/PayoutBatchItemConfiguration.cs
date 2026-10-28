using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class PayoutBatchItemConfiguration : IEntityTypeConfiguration<PayoutBatchItem>
{
    public void Configure(EntityTypeBuilder<PayoutBatchItem> builder)
    {
        builder.ToTable("payout_batch_items");

        builder.Property(i => i.Amount).HasPrecision(10, 2);
        builder.Property(i => i.WorkerName).HasMaxLength(200).IsRequired();
        builder.Property(i => i.ProviderPayoutId).HasMaxLength(100);
        builder.Property(i => i.FailureReason).HasMaxLength(500);

        builder.HasIndex(i => i.PayoutBatchId).HasDatabaseName("ix_payout_batch_items_payout_batch_id");

        // Webhooks arrive keyed by the provider's id, so this lookup is on the hot path.
        builder.HasIndex(i => i.ProviderPayoutId)
            .HasDatabaseName("ix_payout_batch_items_provider_payout_id");

        builder.HasOne(i => i.PayoutBatch)
            .WithMany(b => b.Items)
            .HasForeignKey(i => i.PayoutBatchId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.HiringPostApplication)
            .WithMany()
            .HasForeignKey(i => i.HiringPostApplicationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(i => i.WorkerProfile)
            .WithMany()
            .HasForeignKey(i => i.WorkerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
