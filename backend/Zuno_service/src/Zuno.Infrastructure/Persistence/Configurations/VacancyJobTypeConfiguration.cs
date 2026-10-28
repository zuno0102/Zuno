using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyJobTypeConfiguration : IEntityTypeConfiguration<VacancyJobType>
{
    public void Configure(EntityTypeBuilder<VacancyJobType> builder)
    {
        builder.ToTable("vacancy_job_types");

        builder.Property(t => t.Name).HasMaxLength(60).IsRequired();

        builder.HasIndex(t => t.Name)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_vacancy_job_types_name");

        builder.HasData(VacancySeedData.JobTypes);
    }
}
