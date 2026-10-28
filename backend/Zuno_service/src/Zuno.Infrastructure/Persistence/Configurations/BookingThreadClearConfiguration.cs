using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingThreadClearConfiguration : IEntityTypeConfiguration<BookingThreadClear>
{
    public void Configure(EntityTypeBuilder<BookingThreadClear> builder)
    {
        builder.ToTable("booking_thread_clears");

        builder.HasOne(c => c.Booking)
            .WithMany(b => b.ThreadClears)
            .HasForeignKey(c => c.BookingId)
            .OnDelete(DeleteBehavior.Cascade);

        // One row per person per booking, moved forward each time they clear it again. Without the
        // constraint a second clear would leave two rows and the later one would not reliably win.
        builder.HasIndex(c => new { c.BookingId, c.UserId })
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_booking_thread_clears_booking_user");
    }
}
