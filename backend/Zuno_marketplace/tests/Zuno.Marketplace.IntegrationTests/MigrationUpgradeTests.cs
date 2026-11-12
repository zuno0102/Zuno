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

    [Fact]
    public async Task Upgrade_GivesProductsTheirConditionAndStock_FromTheOldDetail()
    {
        var connectionString = await factory.NewDatabaseAsync();
        await using var db = new MarketplaceDbContext(new DbContextOptionsBuilder<MarketplaceDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync(FourCategories);

        var usedCar = Guid.NewGuid();
        var newSaree = Guid.NewGuid();
        var unsaid = Guid.NewGuid();
        var bananas = Guid.NewGuid();
        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await InsertAsync(connection, usedCar, MarketplaceCatalogSeedData.Products, "Swift", minOrder: null,
                attributes: """[{"Key":"condition","Value":"Used"},{"Key":"brand","Value":"Maruti"}]""");
            await InsertAsync(connection, newSaree, MarketplaceCatalogSeedData.Products, "Silk saree", minOrder: null,
                attributes: """[{"Key":"condition","Value":"New"}]""");
            await InsertAsync(connection, unsaid, MarketplaceCatalogSeedData.Products, "Toy car", minOrder: null);
            await InsertAsync(connection, bananas, MarketplaceCatalogSeedData.B2BWholesale, "Nendran", minOrder: 1);
        }

        await migrator.MigrateAsync();

        var posts = await db.Posts.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(p => p.Id);
        posts[usedCar].Condition.Should().Be(MarketplaceItemCondition.Used);
        posts[usedCar].Quantity.Should().BeNull();
        posts[usedCar].Attributes.Select(a => (a.Key, a.Value)).Should().Equal([("brand", "Maruti")], "the old detail leaves; the rest stay");
        posts[newSaree].Condition.Should().Be(MarketplaceItemCondition.New);
        posts[newSaree].Quantity.Should().Be(1);
        posts[newSaree].Attributes.Should().BeEmpty();
        posts[unsaid].Condition.Should().Be(MarketplaceItemCondition.New, "a product that never said is taken as new");
        posts[unsaid].Quantity.Should().Be(1);
        posts[bananas].Condition.Should().BeNull("B2B keeps no stock");

        var statuses = await db.PostStatuses.AsNoTracking().Select(s => s.Code).ToListAsync();
        statuses.Should().Contain(MarketplacePostStatus.Sold);
    }

    [Fact]
    public async Task StockAndSold_RollsBack_WithSoldAndEmptyStockPosts_AndForwardAgain()
    {
        var connectionString = await factory.NewDatabaseAsync();
        await using var db = new MarketplaceDbContext(new DbContextOptionsBuilder<MarketplaceDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync();

        var sold = Guid.NewGuid();
        var empty = Guid.NewGuid();
        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await InsertAsync(connection, sold, MarketplaceCatalogSeedData.Products, "Swift", minOrder: null);
            await InsertAsync(connection, empty, MarketplaceCatalogSeedData.Products, "Saree", minOrder: null);
            await using var command = new NpgsqlCommand(
                $"UPDATE marketplace_posts SET condition = {(short)MarketplaceItemCondition.Used}, status = {(short)MarketplacePostStatus.Sold} WHERE id = @sold; " +
                $"UPDATE marketplace_posts SET condition = {(short)MarketplaceItemCondition.New}, quantity = 0 WHERE id = @empty;",
                connection);
            command.Parameters.AddWithValue("sold", sold);
            command.Parameters.AddWithValue("empty", empty);
            await command.ExecuteNonQueryAsync();
        }

        await migrator.MigrateAsync(FourCategories);
        await migrator.MigrateAsync();

        var transitions = await db.PostTransitions.AsNoTracking().ToListAsync();
        transitions.Where(t => t.ToStatus == MarketplacePostStatus.Closed).Select(t => t.ActionName).Should().OnlyContain(n => n == "Close");
        transitions.Should().Contain(t => t.ToStatus == MarketplacePostStatus.Sold && t.Condition == MarketplaceItemCondition.Used);
        var posts = await db.Posts.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(p => p.Id);
        posts[sold].Status.Should().Be(MarketplacePostStatus.Closed, "rolling back turned Sold into Closed");
        posts[empty].Quantity.Should().Be(1, "rolling back turned an empty stock into 1");
    }

    [Fact]
    public async Task ShipsToState_TakesTheStateOfChosenDistricts_AndRollsBack()
    {
        var connectionString = await factory.NewDatabaseAsync();
        await using var db = new MarketplaceDbContext(new DbContextOptionsBuilder<MarketplaceDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync(VariantsAndDelivery);

        var local = Guid.NewGuid();
        var anywhere = Guid.NewGuid();
        var kanyakumari = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari");
        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await InsertAsync(connection, local, MarketplaceCatalogSeedData.Products, "Saree", minOrder: null);
            await InsertAsync(connection, anywhere, MarketplaceCatalogSeedData.Products, "Shirt", minOrder: null);
            await using var command = new NpgsqlCommand(
                "UPDATE marketplace_posts SET delivers_everywhere = false, delivery_district_ids = ARRAY[@district]::uuid[], " +
                "address_line = '12 Main Road' WHERE id = @local;",
                connection);
            command.Parameters.AddWithValue("district", kanyakumari);
            command.Parameters.AddWithValue("local", local);
            await command.ExecuteNonQueryAsync();
        }

        await migrator.MigrateAsync();

        var posts = await db.Posts.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(p => p.Id);
        posts[local].DeliversEverywhere.Should().BeFalse();
        posts[local].DeliveryStateId.Should().Be(LocationSeedData.StateId("Tamil Nadu"));
        posts[local].DeliveryDistrictIds.Should().Equal(kanyakumari);
        posts[anywhere].DeliversEverywhere.Should().BeTrue();
        posts[anywhere].DeliveryStateId.Should().BeNull();

        await migrator.MigrateAsync(VariantsAndDelivery);
        await migrator.MigrateAsync();
        (await db.Posts.IgnoreQueryFilters().AsNoTracking().SingleAsync(p => p.Id == local))
            .DeliveryStateId.Should().Be(LocationSeedData.StateId("Tamil Nadu"));
    }

    private const string FourCategories = "20261112070639_MainCategoriesAndSubCategories";
    private const string VariantsAndDelivery = "20261112100833_ProductVariantsDetailsAndDelivery";

    /// <summary>A post as the first release stored it — a retail listing.</summary>
    private static async Task InsertAsync(
        NpgsqlConnection connection, Guid id, Guid categoryId, string title, int? minOrder, string? attributes = null)
    {
        await using var command = new NpgsqlCommand(
            "INSERT INTO marketplace_posts (id, owner_user_id, category_id, kind, status, title, price, trade_type, " +
            "min_order_quantity, district_id, attributes, created_date, is_deleted) " +
            "VALUES (@id, @owner, @category, @kind, @status, @title, 100, @retail, @minOrder, @district, @attributes::jsonb, now(), false)",
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
        command.Parameters.AddWithValue("attributes", (object?)attributes ?? DBNull.Value);
        await command.ExecuteNonQueryAsync();
    }
}
