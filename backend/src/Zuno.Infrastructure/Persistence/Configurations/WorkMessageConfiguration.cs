using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class WorkMessageConfiguration : IEntityTypeConfiguration<WorkMessage>
{
    public void Configure(EntityTypeBuilder<WorkMessage> builder)
    {
        builder.ToTable("work_messages");

        // The same limit as a booking message: room for an address and directions, not a document.
        builder.Property(m => m.Body).HasMaxLength(2000).IsRequired();

        builder.HasOne(m => m.BusinessOwnerProfile)
            .WithMany()
            .HasForeignKey(m => m.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(m => m.WorkerProfile)
            .WithMany()
            .HasForeignKey(m => m.WorkerProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        // Every read is "this pair, oldest first"; unread counts filter on top of it.
        builder.HasIndex(m => new { m.BusinessOwnerProfileId, m.WorkerProfileId, m.CreatedDate });

        // A worker's own list of conversations starts from their side.
        builder.HasIndex(m => new { m.WorkerProfileId, m.CreatedDate });
    }
}
