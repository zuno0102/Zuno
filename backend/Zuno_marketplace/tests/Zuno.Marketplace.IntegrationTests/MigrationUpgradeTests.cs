using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Infrastructure.Persistence;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// The live database was made by the first release. Moving to four main categories must carry its
/// posts across: Vehicles and Property under Products, farm posts made wholesale.
/// </summary>
public class MigrationUpgradeTests(MarketplaceApiFactory factory) : IClassFixture<MarketplaceApiFactory>
{
    private const string FirstRelease = "20261111105857_InitialMarketplace";

    [Fact]
    public async Task Upgrade_MovesFirstReleasePosts_IntoTheNewCategories()
    {
        var connectionString = await factory.NewDatabaseAsync();
        await using var db = new MarketplaceDbContext(new DbContextOptionsBuilder<MarketplaceDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync(FirstRelease);

        var car = Guid.NewGuid();
        var plot = Guid.NewGuid();
        var bananas = Guid.NewGuid();
        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await InsertAsync(connection, car, MarketplaceCatalogSeedData.LegacyVehicles, "Swift", minOrder: null);
            await InsertAsync(connection, plot, MarketplaceCatalogSeedData.LegacyProperty, "10 cents", minOrder: null);
            await InsertAsync(connection, bananas, MarketplaceCatalogSeedData.B2BWholesale, "Nendran", minOrder: null);
        }

        await migrator.MigrateAsync();

        var posts = await db.Posts.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(p => p.Id);
        posts[car].CategoryId.Should().Be(MarketplaceCatalogSeedData.Products);
        posts[car].SubCategoryId.Should().Be(MarketplaceCatalogSeedData.Vehicles);
        posts[plot].CategoryId.Should().Be(MarketplaceCatalogSeedData.Products);
        posts[plot].SubCategoryId.Should().Be(MarketplaceCatalogSeedData.Property);
        posts[bananas].TradeType.Should().Be(MarketplaceTradeType.Wholesale);
        posts[bananas].MinOrderQuantity.Should().Be(1);

        var categories = await db.Categories.AsNoTracking().ToListAsync();
        categories.Where(c => c.IsActive).Select(c => c.Id).Should().BeEquivalentTo(
            [MarketplaceCatalogSeedData.Products, MarketplaceCatalogSeedData.B2BWholesale, MarketplaceCatalogSeedData.NearbyFood, MarketplaceCatalogSeedData.Advertisements]);
        categories.Should().OnlyContain(c => Enum.IsDefined(c.TradeMode));
    }

    /// <summary>A post as the first release stored it — a retail listing.</summary>
    private static async Task InsertAsync(NpgsqlConnection connection, Guid id, Guid categoryId, string title, int? minOrder)
    {
        await using var command = new NpgsqlCommand(
            "INSERT INTO marketplace_posts (id, owner_user_id, category_id, kind, status, title, price, trade_type, " +
            "min_order_quantity, district_id, created_date, is_deleted) " +
            "VALUES (@id, @owner, @category, @kind, @status, @title, 100, @retail, @minOrder, @district, now(), false)",
            connection);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("owner", Guid.NewGuid());
        command.Parameters.AddWithValue("category", categoryId);
        command.Parameters.AddWithValue("kind", (short)MarketplacePostKind.Listing);
        command.Parameters.AddWithValue("status", (short)MarketplacePostStatus.Active);
        command.Parameters.AddWithValue("title", title);
        command.Parameters.AddWithValue("retail", (short)MarketplaceTradeType.Retail);
        command.Parameters.AddWithValue("minOrder", (object?)minOrder ?? DBNull.Value);
        command.Parameters.AddWithValue("district", LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari"));
        await command.ExecuteNonQueryAsync();
    }
}
