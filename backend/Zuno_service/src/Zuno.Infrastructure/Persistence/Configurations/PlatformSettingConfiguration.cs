using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Application.Common.Settings;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class PlatformSettingConfiguration : IEntityTypeConfiguration<PlatformSetting>
{
    public void Configure(EntityTypeBuilder<PlatformSetting> builder)
    {
        builder.ToTable("platform_settings");

        builder.Property(s => s.Key).HasMaxLength(100).IsRequired();
        builder.Property(s => s.Value).HasMaxLength(500).IsRequired();
        builder.Property(s => s.Description).HasMaxLength(300).IsRequired();

        // One row per rule: two would leave the store guessing which applies.
        builder.HasIndex(s => s.Key)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_platform_settings_key");

        builder.HasData(PlatformSettingSeedData.From(PlatformRules.Defaults));
    }
}
