using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingAgreementProposalConfiguration
    : IEntityTypeConfiguration<BookingAgreementProposal>
{
    public void Configure(EntityTypeBuilder<BookingAgreementProposal> builder)
    {
        builder.ToTable("booking_agreement_proposals");

        builder.Property(p => p.Message).HasMaxLength(500);

        // Same precision as Booking.PriceQuoted, which is what an accepted offer is copied into.
        builder.Property(p => p.Price).HasPrecision(10, 2);

        builder.HasOne(p => p.Booking)
            .WithMany(b => b.AgreementProposals)
            .HasForeignKey(p => p.BookingId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(p => p.BookingId);

        // The structural guarantee behind "counter as many times as you like": at most one offer
        // can be open on an order at a time. The handlers supersede the previous one before
        // raising the next, but a double-tap or two requests racing would otherwise leave two on
        // the table and no way to say which was agreed. The database refuses instead.
        builder.HasIndex(p => p.BookingId)
            .IsUnique()
            .HasFilter("proposal_status = 1 AND is_deleted = false")
            .HasDatabaseName("ux_booking_agreement_proposals_open");
    }
}
