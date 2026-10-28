using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class PayoutBatchConfiguration : IEntityTypeConfiguration<PayoutBatch>
{
    public void Configure(EntityTypeBuilder<PayoutBatch> builder)
    {
        builder.ToTable("payout_batches");

        builder.Property(b => b.TotalAmount).HasPrecision(12, 2);
        builder.Property(b => b.ProviderOrderId).HasMaxLength(100);
        builder.Property(b => b.ProviderPaymentId).HasMaxLength(100);
        builder.Property(b => b.IdempotencyKey).HasMaxLength(64).IsRequired();

        // The guarantee against paying twice: the same key can only ever produce one batch.
        builder.HasIndex(b => b.IdempotencyKey)
            .IsUnique()
            .HasDatabaseName("ux_payout_batches_idempotency_key");

        builder.HasIndex(b => b.HiringPostId).HasDatabaseName("ix_payout_batches_hiring_post_id");
        builder.HasIndex(b => b.ProviderOrderId).HasDatabaseName("ix_payout_batches_provider_order_id");

        builder.HasOne(b => b.HiringPost)
            .WithMany()
            .HasForeignKey(b => b.HiringPostId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(b => b.BusinessOwnerProfile)
            .WithMany()
            .HasForeignKey(b => b.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
