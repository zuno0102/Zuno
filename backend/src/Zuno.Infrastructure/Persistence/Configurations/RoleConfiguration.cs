using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Infrastructure.Persistence.Seed;

namespace Zuno.Infrastructure.Persistence.Configurations;

public class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    private static readonly DateTimeOffset SeedDate = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.ToTable("roles");

        builder.Property(r => r.Name).HasMaxLength(50).IsRequired();
        builder.Property(r => r.Description).HasMaxLength(200);

        builder.HasIndex(r => r.Name).IsUnique();

        builder.HasData(
            new Role
            {
                Id = WellKnownRoleIds.Customer,
                Name = nameof(UserRoleType.Customer),
                Description = "Books local services.",
                CreatedDate = SeedDate,
                IsDeleted = false,
                Status = EntityStatus.Active,
            },
            new Role
            {
                Id = WellKnownRoleIds.BusinessOwner,
                Name = nameof(UserRoleType.BusinessOwner),
                Description = "Receives bookings and posts worker hiring requirements.",
                CreatedDate = SeedDate,
                IsDeleted = false,
                Status = EntityStatus.Active,
            },
            new Role
            {
                Id = WellKnownRoleIds.Worker,
                Name = nameof(UserRoleType.Worker),
                Description = "Searches and applies for jobs.",
                CreatedDate = SeedDate,
                IsDeleted = false,
                Status = EntityStatus.Active,
            },
            new Role
            {
                Id = WellKnownRoleIds.SuperAdmin,
                Name = nameof(UserRoleType.SuperAdmin),
                Description = "Manages the complete platform.",
                CreatedDate = SeedDate,
                IsDeleted = false,
                Status = EntityStatus.Active,
            });
    }
}
