using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyRequirementConfiguration : IEntityTypeConfiguration<VacancyRequirement>
{
    public void Configure(EntityTypeBuilder<VacancyRequirement> builder)
    {
        builder.ToTable("vacancy_requirements", t =>
            t.HasCheckConstraint("ck_vacancy_requirements_kind", "kind BETWEEN 1 AND 4"));

        builder.Property(r => r.Prompt).HasMaxLength(200).IsRequired();

        builder.HasIndex(r => r.VacancyId).HasDatabaseName("ix_vacancy_requirements_vacancy_id");

        builder.HasOne(r => r.Vacancy)
            .WithMany(v => v.Requirements)
            .HasForeignKey(r => r.VacancyId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
