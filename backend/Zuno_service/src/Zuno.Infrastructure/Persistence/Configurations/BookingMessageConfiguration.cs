using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingMessageConfiguration : IEntityTypeConfiguration<BookingMessage>
{
    public void Configure(EntityTypeBuilder<BookingMessage> builder)
    {
        builder.ToTable("booking_messages");

        // Long enough for an address and directions, short enough that nobody pastes a document in.
        builder.Property(m => m.Body).HasMaxLength(2000).IsRequired();

        builder.HasOne(m => m.Booking)
            .WithMany(b => b.Messages)
            .HasForeignKey(m => m.BookingId)
            .OnDelete(DeleteBehavior.Cascade);

        // Every read of a thread is "this booking, oldest first", and every unread count is a filter
        // on top of it.
        builder.HasIndex(m => new { m.BookingId, m.CreatedDate });
    }
}
