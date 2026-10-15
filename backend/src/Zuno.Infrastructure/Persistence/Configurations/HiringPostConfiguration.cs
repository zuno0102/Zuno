using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class HiringPostConfiguration : IEntityTypeConfiguration<HiringPost>
{
    public void Configure(EntityTypeBuilder<HiringPost> builder)
    {
        builder.ToTable("hiring_posts");

        builder.Property(p => p.Title).HasMaxLength(200).IsRequired();
        builder.Property(p => p.Description).HasMaxLength(1000);
        builder.Property(p => p.ImageUrl).HasMaxLength(500);
        builder.Property(p => p.Location).HasMaxLength(300);
        builder.Property(p => p.SalaryAmount).HasPrecision(10, 2);

        builder.HasIndex(p => p.BusinessOwnerProfileId).HasDatabaseName("ix_hiring_posts_business_owner_profile_id");
        builder.HasIndex(p => p.HiringPostStatus).HasDatabaseName("ix_hiring_posts_hiring_post_status");

        builder.HasIndex(p => p.BookingId).HasDatabaseName("ix_hiring_posts_booking_id");
        builder.Property(p => p.Latitude).HasColumnType("numeric(9,6)");
        builder.Property(p => p.Longitude).HasColumnType("numeric(9,6)");

        // The index that actually earns its keep on the worker feed, which always narrows on status
        // and date before it looks at coordinates.
        builder.HasIndex(p => new { p.HiringPostStatus, p.EventDate })
            .HasDatabaseName("ix_hiring_posts_status_event_date");

        // Only the leading column can be range-scanned, so this helps the latitude half of a
        // bounding box and nothing more. A real 2D index means PostGIS and GiST, which is the
        // upgrade path once the bounding-box row cap starts to bite.
        builder.HasIndex(p => new { p.Latitude, p.Longitude })
            .HasDatabaseName("ix_hiring_posts_latitude_longitude");

        builder.HasIndex(p => p.DistrictId).HasDatabaseName("ix_hiring_posts_district_id");

        // Restrict: a district is reference data and must never take posts with it.
        builder.HasOne(p => p.District)
            .WithMany()
            .HasForeignKey(p => p.DistrictId)
            .OnDelete(DeleteBehavior.Restrict);


        // Restrict: retiring a sub-category must never delete the posts filed under it.
        builder.HasOne(p => p.ServiceSubCategory)
            .WithMany()
            .HasForeignKey(p => p.ServiceSubCategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(p => p.BusinessOwnerProfile)
            .WithMany()
            .HasForeignKey(p => p.BusinessOwnerProfileId)
            .OnDelete(DeleteBehavior.Cascade);

        // SetNull rather than Cascade: a hiring post carries agreed wages and payout history, and
        // losing a booking must never delete the record of what workers were owed for it.
        builder.HasOne(p => p.Booking)
            .WithMany(b => b!.HiringPosts)
            .HasForeignKey(p => p.BookingId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
