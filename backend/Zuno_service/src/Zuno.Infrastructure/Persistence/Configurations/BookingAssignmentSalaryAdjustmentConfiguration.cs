using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingAssignmentSalaryAdjustmentConfiguration : IEntityTypeConfiguration<BookingAssignmentSalaryAdjustment>
{
    public void Configure(EntityTypeBuilder<BookingAssignmentSalaryAdjustment> builder)
    {
        builder.ToTable("booking_assignment_salary_adjustments");

        builder.Property(a => a.PreviousAmount).HasPrecision(10, 2);
        builder.Property(a => a.NewAmount).HasPrecision(10, 2);
        builder.Property(a => a.Reason).HasMaxLength(300);

        builder.HasIndex(a => a.BookingWorkerAssignmentId)
            .HasDatabaseName("ix_booking_assignment_salary_adjustments_assignment_id");

        builder.HasOne(a => a.BookingWorkerAssignment)
            .WithMany(a => a.SalaryAdjustments)
            .HasForeignKey(a => a.BookingWorkerAssignmentId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
