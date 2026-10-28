using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyApplicationConfiguration : IEntityTypeConfiguration<VacancyApplication>
{
    public void Configure(EntityTypeBuilder<VacancyApplication> builder)
    {
        builder.ToTable("vacancy_applications");

        builder.Property(a => a.BusinessNote).HasMaxLength(500);

        // One live application per worker per vacancy — the database refuses a double-tapped Apply even
        // when two requests race. Filtered, so a worker who withdrew can apply again.
        builder.HasIndex(a => new { a.VacancyId, a.WorkerProfileId })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_vacancy_applications_vacancy_worker");

        builder.HasIndex(a => a.WorkerProfileId).HasDatabaseName("ix_vacancy_applications_worker_profile_id");

        builder.HasOne(a => a.Vacancy)
            .WithMany(v => v.Applications)
            .HasForeignKey(a => a.VacancyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(a => a.WorkerProfile)
            .WithMany()
            .HasForeignKey(a => a.WorkerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
