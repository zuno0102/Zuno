using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.ToTable("notifications");

        // A lock-screen line. Anything longer is truncated by the phone before anybody reads it.
        builder.Property(n => n.Title).HasMaxLength(200).IsRequired();
        builder.Property(n => n.Body).HasMaxLength(500).IsRequired();

        builder.HasOne(n => n.User)
            .WithMany()
            .HasForeignKey(n => n.UserId)
            // Deleting an account takes its notifications with it. They are addressed to one person
            // and mean nothing without them.
            .OnDelete(DeleteBehavior.Cascade);

        // The list: this person's notifications, newest first. Every read starts here.
        builder.HasIndex(n => new { n.UserId, n.CreatedDate });

        // The badge: how many are unread. Asked for on every app resume, so it gets its own filtered
        // index rather than counting its way through a person's whole history.
        builder.HasIndex(n => new { n.UserId, n.ReadAt })
            .HasFilter("read_at IS NULL");
    }
}
