using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class OrderStageDefinitionConfiguration : IEntityTypeConfiguration<OrderStageDefinition>
{
    public void Configure(EntityTypeBuilder<OrderStageDefinition> builder)
    {
        builder.ToTable("order_stages");

        builder.Property(s => s.DisplayName).HasMaxLength(60).IsRequired();
        // A key the apps map to their theme ("success", "danger"), not a colour value.
        builder.Property(s => s.Tone).HasMaxLength(20).IsRequired();

        // One row per stage: two would leave the apps guessing which name to show.
        builder.HasIndex(s => s.Stage)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_order_stages_stage");

        builder.HasData(OrderStageSeedData.All);
    }
}
