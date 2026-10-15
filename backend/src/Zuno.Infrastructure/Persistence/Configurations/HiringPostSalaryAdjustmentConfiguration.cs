using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class HiringPostSalaryAdjustmentConfiguration : IEntityTypeConfiguration<HiringPostSalaryAdjustment>
{
    public void Configure(EntityTypeBuilder<HiringPostSalaryAdjustment> builder)
    {
        builder.ToTable("hiring_post_salary_adjustments");

        builder.Property(a => a.PreviousAmount).HasPrecision(10, 2);
        builder.Property(a => a.NewAmount).HasPrecision(10, 2);
        builder.Property(a => a.Reason).HasMaxLength(300);

        builder.HasIndex(a => a.HiringPostApplicationId)
            .HasDatabaseName("ix_hiring_post_salary_adjustments_hiring_post_application_id");

        builder.HasOne(a => a.HiringPostApplication)
            .WithMany(a => a.SalaryAdjustments)
            .HasForeignKey(a => a.HiringPostApplicationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
