using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Zuno.Rent.Infrastructure.Persistence;

/// <summary>
/// Lets <c>dotnet ef migrations add</c> build the context without starting the API. Generating a
/// migration never connects, so the connection string is only a placeholder.
/// </summary>
public class RentDbContextDesignFactory : IDesignTimeDbContextFactory<RentDbContext>
{
    public RentDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<RentDbContext>()
            .UseNpgsql("Host=localhost;Database=zuno_rent_design")
            .UseSnakeCaseNamingConvention()
            .Options);
}
