using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Zuno.Marketplace.Infrastructure.Persistence;

/// <summary>
/// Lets <c>dotnet ef migrations add</c> build the context without starting the API. Generating a
/// migration never connects, so the connection string is only a placeholder.
/// </summary>
public class MarketplaceDbContextDesignFactory : IDesignTimeDbContextFactory<MarketplaceDbContext>
{
    public MarketplaceDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<MarketplaceDbContext>()
            .UseNpgsql("Host=localhost;Database=zuno_marketplace_design")
            .UseSnakeCaseNamingConvention()
            .Options);
}
