using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class ThemeColorConfiguration : IEntityTypeConfiguration<ThemeColor>
{
    public void Configure(EntityTypeBuilder<ThemeColor> builder)
    {
        builder.ToTable("theme_colors");

        builder.Property(c => c.Key).HasMaxLength(80).IsRequired();
        builder.Property(c => c.LightValue).HasMaxLength(9).IsRequired();
        builder.Property(c => c.DarkValue).HasMaxLength(9).IsRequired();

        builder.HasIndex(c => c.Key)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_theme_colors_key");

        builder.HasData(UiConfigSeedData.ColorRows);
    }
}
