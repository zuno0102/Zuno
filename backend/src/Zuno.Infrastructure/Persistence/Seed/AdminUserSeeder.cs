using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Zuno.Domain.Entities;

namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// Creates the first Super Admin account on startup, since SuperAdmin is deliberately excluded
/// from self-registration. Runs only when no Super Admin exists yet and credentials are configured.
/// </summary>
public static class AdminUserSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();

        var dbContext = scope.ServiceProvider.GetRequiredService<ZunoDbContext>();
        var passwordHasher = scope.ServiceProvider.GetRequiredService<Application.Common.Interfaces.IPasswordHasher>();
        var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(AdminUserSeeder));

        var alreadyExists = await dbContext.Users
            .AnyAsync(u => u.RoleId == WellKnownRoleIds.SuperAdmin);

        if (alreadyExists)
        {
            return;
        }

        var email = configuration["AdminSeed:Email"];
        var password = configuration["AdminSeed:Password"];

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning(
                "No Super Admin account exists and AdminSeed:Email/AdminSeed:Password are not configured. Skipping seed.");
            return;
        }

        var admin = new User
        {
            Email = email,
            PasswordHash = passwordHasher.Hash(password),
            FirstName = "Zuno",
            LastName = "Admin",
            RoleId = WellKnownRoleIds.SuperAdmin,
            EmailConfirmed = true,
        };
        admin.AdminProfile = new AdminProfile { UserId = admin.Id, AdminLevel = 1 };

        dbContext.Users.Add(admin);
        await dbContext.SaveChangesAsync();

        logger.LogInformation("Seeded initial Super Admin account for {Email}.", email);
    }
}
