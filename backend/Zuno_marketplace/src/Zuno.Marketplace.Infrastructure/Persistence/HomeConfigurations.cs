using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.Infrastructure.Persistence;

public class MarketplaceHomeSectionConfiguration : IEntityTypeConfiguration<MarketplaceHomeSection>
{
    public void Configure(EntityTypeBuilder<MarketplaceHomeSection> builder)
    {
        builder.ToTable("ref_marketplace_home_sections", t =>
        {
            t.HasCheckConstraint("ck_ref_marketplace_home_sections_source", "source BETWEEN 1 AND 12");
            t.HasCheckConstraint("ck_ref_marketplace_home_sections_layout", "layout BETWEEN 1 AND 4");
            t.HasCheckConstraint("ck_ref_marketplace_home_sections_item_count", "item_count BETWEEN 1 AND 50");
        });
        builder.HasKey(s => s.Code);
        builder.Property(s => s.Code).HasMaxLength(40);
        builder.Property(s => s.Title).HasMaxLength(60).IsRequired();
        builder.Property(s => s.Parameter).HasMaxLength(100);
        builder.HasData(MarketplaceHomeSeedData.Sections);
    }
}
