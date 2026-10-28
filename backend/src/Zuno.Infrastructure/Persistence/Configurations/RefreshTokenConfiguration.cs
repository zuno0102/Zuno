using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("refresh_tokens");

        builder.Property(rt => rt.TokenHash).HasMaxLength(255).IsRequired();
        builder.Property(rt => rt.CreatedByIp).HasMaxLength(45);
        builder.Property(rt => rt.RevokedByIp).HasMaxLength(45);
        builder.Property(rt => rt.ReasonRevoked).HasMaxLength(200);

        // Postgres's own row version (the xmin system column — no column is added). Two refreshes
        // racing with one token both read it unused; with this, only the first can save its
        // rotation and the second fails, so a token is used once even under a race.
        builder.Property<uint>("xmin").IsRowVersion();

        builder.HasIndex(rt => rt.TokenHash).IsUnique().HasDatabaseName("ux_refresh_tokens_token_hash");
        builder.HasIndex(rt => new { rt.UserId, rt.ExpiresAt }).HasDatabaseName("ix_refresh_tokens_user_id_expires_at");

        builder.HasOne(rt => rt.User)
            .WithMany(u => u.RefreshTokens)
            .HasForeignKey(rt => rt.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(rt => rt.ReplacedByToken)
            .WithMany()
            .HasForeignKey(rt => rt.ReplacedByTokenId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
