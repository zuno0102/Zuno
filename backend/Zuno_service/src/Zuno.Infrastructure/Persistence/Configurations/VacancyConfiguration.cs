using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class VacancyConfiguration : IEntityTypeConfiguration<Vacancy>
{
    public void Configure(EntityTypeBuilder<Vacancy> builder)
    {
        builder.ToTable("vacancies", t =>
        {
            t.HasCheckConstraint("ck_vacancies_openings", "openings >= 1");
            t.HasCheckConstraint("ck_vacancies_salary_min", "salary_min > 0");
            t.HasCheckConstraint("ck_vacancies_salary_range", "salary_max IS NULL OR salary_max >= salary_min");
            t.HasCheckConstraint("ck_vacancies_working_days", "working_days_per_week BETWEEN 1 AND 7");
        });

        builder.Property(v => v.Title).HasMaxLength(150).IsRequired();
        builder.Property(v => v.Description).HasMaxLength(2000);
        builder.Property(v => v.Location).HasMaxLength(300);
        builder.Property(v => v.SalaryMin).HasPrecision(10, 2);
        builder.Property(v => v.SalaryMax).HasPrecision(10, 2);
        builder.Property(v => v.FeeAmount).HasPrecision(10, 2);
        builder.Property(v => v.Latitude).HasColumnType("numeric(9,6)");
        builder.Property(v => v.Longitude).HasColumnType("numeric(9,6)");
        builder.Property(v => v.PendingOrderId).HasMaxLength(100);
        builder.Property(v => v.LastPaymentId).HasMaxLength(100);

        builder.HasIndex(v => v.BusinessOwnerProfileId).HasDatabaseName("ix_vacancies_business_owner_profile_id");

        // The worker feed: live vacancies, newest first. Status leads because the feed always narrows
        // on it; the expiry then range-scans.
        builder.HasIndex(v => new { v.VacancyStatus, v.ExpiresAt })
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ix_vacancies_status_expires_at");

        builder.HasIndex(v => new { v.Latitude, v.Longitude }).HasDatabaseName("ix_vacancies_latitude_longitude");
        builder.HasIndex(v => v.DistrictId).HasDatabaseName("ix_vacancies_district_id");

        builder.HasOne(v => v.BusinessOwnerProfile)
            .WithMany()
            .HasForeignKey(v => v.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        // Restrict on every reference table: retiring a type, plan or district never takes vacancies with it.
        builder.HasOne(v => v.VacancyJobType)
            .WithMany()
            .HasForeignKey(v => v.VacancyJobTypeId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(v => v.VacancyFeePlan)
            .WithMany()
            .HasForeignKey(v => v.VacancyFeePlanId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(v => v.District)
            .WithMany()
            .HasForeignKey(v => v.DistrictId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(v => v.ServiceSubCategory)
            .WithMany()
            .HasForeignKey(v => v.ServiceSubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
