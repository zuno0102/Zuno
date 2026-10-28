using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class LevelDefinitionConfiguration : IEntityTypeConfiguration<LevelDefinition>
{
    public void Configure(EntityTypeBuilder<LevelDefinition> builder)
    {
        builder.ToTable("level_definitions");

        builder.Property(l => l.Name).HasMaxLength(60).IsRequired();
        builder.Property(l => l.MinRating).HasPrecision(3, 2);
        builder.Property(l => l.MinAnsweredRate).HasPrecision(4, 3);

        // One rung per level per ladder: two would leave the store guessing which badge applies.
        builder.HasIndex(l => new { l.Audience, l.Level })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_level_definitions_audience_level");

        builder.HasData(LevelDefinitionSeedData.Rows);
    }
}
