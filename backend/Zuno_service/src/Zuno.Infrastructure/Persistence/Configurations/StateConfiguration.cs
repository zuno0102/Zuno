using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class StateConfiguration : IEntityTypeConfiguration<State>
{
    public void Configure(EntityTypeBuilder<State> builder)
    {
        builder.ToTable("states");

        builder.Property(s => s.Name).HasMaxLength(100).IsRequired();

        builder.HasIndex(s => s.Name)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_states_name");

        builder.HasData(StateSeedData.All);
    }
}
