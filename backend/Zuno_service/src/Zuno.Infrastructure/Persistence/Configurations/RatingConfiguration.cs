using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class RatingConfiguration : IEntityTypeConfiguration<Rating>
{
    public void Configure(EntityTypeBuilder<Rating> builder)
    {
        builder.ToTable("ratings", t => t.HasCheckConstraint("ck_ratings_score_range", "score >= 1 AND score <= 5"));

        builder.Property(r => r.Comment).HasMaxLength(1000);

        builder.HasIndex(r => r.BookingId)
            .IsUnique()
            .HasFilter("is_deleted = false")
            .HasDatabaseName("ux_ratings_booking_id");

        builder.HasIndex(r => r.BusinessOwnerProfileId).HasDatabaseName("ix_ratings_business_owner_profile_id");

        builder.HasOne(r => r.Booking)
            .WithOne(b => b.Rating)
            .HasForeignKey<Rating>(r => r.BookingId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.CustomerProfile)
            .WithMany()
            .HasForeignKey(r => r.CustomerProfileId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.BusinessOwnerProfile)
            .WithMany()
            .HasForeignKey(r => r.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
