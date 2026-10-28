using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class DistrictConfiguration : IEntityTypeConfiguration<District>
{
    public void Configure(EntityTypeBuilder<District> builder)
    {
        builder.ToTable("districts");

        builder.Property(d => d.Name).HasMaxLength(100).IsRequired();

        // numeric(9,6), matching WorkerProfile and Address — 6 places is about 11cm, far finer
        // than a district centre warrants, but consistency beats a bespoke precision here.
        builder.Property(d => d.CentreLatitude).HasColumnType("numeric(9,6)");
        builder.Property(d => d.CentreLongitude).HasColumnType("numeric(9,6)");

        builder.HasIndex(d => d.StateId).HasDatabaseName("ix_districts_state_id");

        builder.HasOne(d => d.State)
            .WithMany(s => s.Districts)
            .HasForeignKey(d => d.StateId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasData(DistrictSeedData.All);
    }
}
