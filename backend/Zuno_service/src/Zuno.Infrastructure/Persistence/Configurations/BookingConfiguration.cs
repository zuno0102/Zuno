using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class BookingConfiguration : IEntityTypeConfiguration<Booking>
{
    public void Configure(EntityTypeBuilder<Booking> builder)
    {
        builder.ToTable("bookings");

        builder.Property(b => b.Notes).HasMaxLength(1000);
        builder.Property(b => b.CancellationReason).HasMaxLength(500);
        builder.Property(b => b.PriceQuoted).HasPrecision(10, 2);

        builder.HasIndex(b => b.CustomerProfileId).HasDatabaseName("ix_bookings_customer_profile_id");
        builder.HasIndex(b => b.BusinessOwnerProfileId).HasDatabaseName("ix_bookings_business_owner_profile_id");
        builder.HasIndex(b => b.BookingStatus).HasDatabaseName("ix_bookings_booking_status");

        builder.HasOne(b => b.CustomerProfile)
            .WithMany(cp => cp.Bookings)
            .HasForeignKey(b => b.CustomerProfileId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(b => b.BusinessOwnerProfile)
            .WithMany(bp => bp.Bookings)
            .HasForeignKey(b => b.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(b => b.BusinessService)
            .WithMany()
            .HasForeignKey(b => b.BusinessServiceId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(b => b.BusinessServiceVariant)
            .WithMany()
            .HasForeignKey(b => b.BusinessServiceVariantId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(b => b.Address)
            .WithMany()
            .HasForeignKey(b => b.AddressId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
