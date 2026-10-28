using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class DisplayLabelConfiguration : IEntityTypeConfiguration<DisplayLabel>
{
    public void Configure(EntityTypeBuilder<DisplayLabel> builder)
    {
        builder.ToTable("display_labels");

        builder.Property(l => l.Group).HasMaxLength(80).IsRequired();
        builder.Property(l => l.Code).HasMaxLength(60).IsRequired();
        builder.Property(l => l.Label).HasMaxLength(200).IsRequired();
        builder.Property(l => l.ShortLabel).HasMaxLength(60);
        builder.Property(l => l.Detail).HasMaxLength(300);
        builder.Property(l => l.Tone).HasMaxLength(20);
        builder.Property(l => l.IconName).HasMaxLength(60);

        // One wording per code per group: two would leave the app guessing which to show.
        builder.HasIndex(l => new { l.Group, l.Code })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_display_labels_group_code");

        builder.HasData(UiConfigSeedData.LabelRows);
    }
}
