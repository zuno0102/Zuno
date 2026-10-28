using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyFeePlanConfiguration : IEntityTypeConfiguration<VacancyFeePlan>
{
    public void Configure(EntityTypeBuilder<VacancyFeePlan> builder)
    {
        builder.ToTable("vacancy_fee_plans", t =>
        {
            t.HasCheckConstraint("ck_vacancy_fee_plans_amount", "amount >= 0");
            t.HasCheckConstraint("ck_vacancy_fee_plans_listing_days", "listing_days > 0");
        });

        builder.Property(p => p.Name).HasMaxLength(60).IsRequired();
        builder.Property(p => p.Amount).HasPrecision(10, 2);

        builder.HasData(VacancySeedData.FeePlans);
    }
}
