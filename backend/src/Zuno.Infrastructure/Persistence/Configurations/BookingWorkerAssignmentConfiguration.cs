using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingWorkerAssignmentConfiguration : IEntityTypeConfiguration<BookingWorkerAssignment>
{
    public void Configure(EntityTypeBuilder<BookingWorkerAssignment> builder)
    {
        builder.ToTable("booking_worker_assignments");

        builder.Property(a => a.Role).HasMaxLength(100);

        // Same precision as a hiring post's agreed salary, which this sits beside in the same
        // rollup — two ways of recording the same kind of debt.
        builder.Property(a => a.AgreedSalaryAmount).HasPrecision(10, 2);

        builder.HasIndex(a => a.BookingId).HasDatabaseName("ix_booking_worker_assignments_booking_id");
        builder.HasIndex(a => a.WorkerProfileId).HasDatabaseName("ix_booking_worker_assignments_worker_profile_id");

        builder.HasOne(a => a.Booking)
            .WithMany(b => b.WorkerAssignments)
            .HasForeignKey(a => a.BookingId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(a => a.WorkerProfile)
            .WithMany(wp => wp.BookingAssignments)
            .HasForeignKey(a => a.WorkerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
