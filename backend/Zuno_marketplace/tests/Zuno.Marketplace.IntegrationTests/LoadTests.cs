using System.Diagnostics;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit.Abstractions;
using Zuno.Marketplace.Domain.Enums;
using Zuno.Marketplace.Infrastructure.Persistence;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.IntegrationTests;

/// <summary>
/// The business screens with a busy Marketplace behind them: 2,000 businesses with 50 posts each,
/// and one big seller with 5,000 posts, colours and sizes on many. Every screen's request must stay
/// fast, and its query must find the rows by index rather than reading the whole table.
/// </summary>
[Trait("Category", "Load")]
public class LoadTests(MarketplaceApiFactory factory, ITestOutputHelper output) : IClassFixture<MarketplaceApiFactory>
{
    private const int Businesses = 2_000;
    private const int PostsEach = 50;
    private const int BigSellerPosts = 5_000;

    /// <summary>Slowest of the timed calls allowed, in-process on a local database (no network).</summary>
    private static readonly TimeSpan Budget = TimeSpan.FromMilliseconds(250);

    private static readonly Guid BigSeller = Guid.Parse("b16b16b1-0000-0000-0000-000000000001");

    [Fact]
    public async Task BusyMarketplace_EveryBusinessScreen_StaysFast_AndUsesIndexes()
    {
        await SeedAsync();
        var client = factory.ClientFor(BigSeller);
        var products = MarketplaceCatalogSeedData.Products;

        var screens = new (string Name, Func<Task<HttpResponseMessage>> Call)[]
        {
            ("Posts list, first page", () => client.GetAsync("/api/v1/business/marketplace")),
            ("Posts list, page 40", () => client.GetAsync("/api/v1/business/marketplace?page=40")),
            ("Orders › Products › Active", () => client.GetAsync($"/api/v1/business/marketplace?categoryId={products}&status=Active")),
            ("Home tiles (summary)", () => client.GetAsync("/api/v1/business/marketplace/summary")),
            ("Categories", () => client.GetAsync("/api/v1/marketplace-categories")),
            ("Options", () => client.GetAsync("/api/v1/marketplace-options")),
        };

        var slow = new List<string>();
        foreach (var (name, call) in screens)
        {
            (await call()).EnsureSuccessStatusCode(); // warm: first JIT and connection
            var times = new List<TimeSpan>();
            for (var i = 0; i < 15; i++)
            {
                var watch = Stopwatch.StartNew();
                (await call()).EnsureSuccessStatusCode();
                times.Add(watch.Elapsed);
            }

            times.Sort();
            var median = times[times.Count / 2];
            var worst = times[^1];
            output.WriteLine($"{name,-30} median {median.TotalMilliseconds,6:N1} ms   worst {worst.TotalMilliseconds,6:N1} ms");
            if (median > Budget)
            {
                slow.Add($"{name}: median {median.TotalMilliseconds:N0} ms");
            }
        }

        // A change, timed too: the stock of one of the big seller's products.
        Guid postId;
        using (var scope = factory.Services.CreateScope())
        {
            postId = await scope.ServiceProvider.GetRequiredService<MarketplaceDbContext>().Posts
                .Where(p => p.OwnerUserId == BigSeller && p.Condition == MarketplaceItemCondition.New
                    && p.Status == MarketplacePostStatus.Active && !p.Variants.Any())
                .Select(p => p.Id)
                .FirstAsync();
        }

        var stock = 7;
        Task<HttpResponseMessage> UpdateStock() =>
            client.PatchAsJsonAsync($"/api/v1/business/marketplace/{postId}/stock", new { quantity = stock++ });
        (await UpdateStock()).EnsureSuccessStatusCode(); // warm
        var stockTimes = new List<TimeSpan>();
        for (var i = 0; i < 10; i++)
        {
            var watch = Stopwatch.StartNew();
            (await UpdateStock()).EnsureSuccessStatusCode();
            stockTimes.Add(watch.Elapsed);
        }

        stockTimes.Sort();
        var stockMedian = stockTimes[stockTimes.Count / 2];
        output.WriteLine($"{"Update stock",-30} median {stockMedian.TotalMilliseconds,6:N1} ms   worst {stockTimes[^1].TotalMilliseconds,6:N1} ms");
        if (stockMedian > Budget)
        {
            slow.Add($"Update stock: median {stockMedian.TotalMilliseconds:N0} ms");
        }

        slow.Should().BeEmpty("every business screen answers within {0} ms", Budget.TotalMilliseconds);
        await ShouldUseIndexesAsync();
    }

    /// <summary>The owner's queries reach the rows through an index, never a full read of 100,000 posts.</summary>
    private async Task ShouldUseIndexesAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MarketplaceDbContext>();
        var connection = db.Database.GetDbConnection();
        await connection.OpenAsync();

        var queries = new Dictionary<string, string>
        {
            ["list"] = $"SELECT id FROM marketplace_posts WHERE owner_user_id = '{BigSeller}' AND NOT is_deleted ORDER BY created_date DESC LIMIT 20",
            ["summary"] = $"SELECT category_id, count(*) FROM marketplace_posts WHERE owner_user_id = '{BigSeller}' AND NOT is_deleted GROUP BY category_id",
            // As the app asks it, with the soft-delete filter. A small table may rightly be read
            // whole, so scans are switched off here: the question is only whether an index can serve it.
            ["variants"] = "SELECT * FROM marketplace_post_variants WHERE post_id = '00000000-0000-0000-0000-000000000001' AND NOT is_deleted",
        };
        foreach (var (name, sql) in queries)
        {
            await using var command = connection.CreateCommand();
            command.CommandText = (name == "variants" ? "SET enable_seqscan = off; " : "SET enable_seqscan = on; ") + "EXPLAIN " + sql;
            var plan = new List<string>();
            await using (var reader = await command.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    plan.Add(reader.GetString(0));
                }
            }

            output.WriteLine($"-- {name}\n{string.Join('\n', plan)}");
            string.Join('\n', plan).Should().NotMatchRegex(@"Seq Scan on marketplace_post(s|_variants)\b", $"the {name} query finds its rows by index");
        }
    }

    /// <summary>Posts written straight into the table — the API's own rules are tested elsewhere.</summary>
    private async Task SeedAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MarketplaceDbContext>();
        var district = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari");
        var categories = new[]
        {
            MarketplaceCatalogSeedData.Products, MarketplaceCatalogSeedData.B2BWholesale,
            MarketplaceCatalogSeedData.NearbyFood, MarketplaceCatalogSeedData.Advertisements,
        };
        db.Database.SetCommandTimeout(TimeSpan.FromMinutes(5));

        // Everyone's posts, then the big seller's. Products are new with stock; one in five paused.
        // Built from this test's own constants and seeded ids, never from input.
        var seed = $"""
            INSERT INTO marketplace_posts (id, owner_user_id, category_id, kind, status, title, price, trade_type,
                min_order_quantity, condition, quantity, district_id, created_date, is_deleted, starts_at, ends_at)
            SELECT gen_random_uuid(),
                   CASE WHEN n <= {Businesses * PostsEach} THEN md5('owner' || (n % {Businesses}))::uuid ELSE '{BigSeller}'::uuid END,
                   (ARRAY['{categories[0]}','{categories[1]}','{categories[2]}','{categories[3]}']::uuid[])[1 + n % 4],
                   CASE n % 4 WHEN 2 THEN {(short)MarketplacePostKind.FoodOffer} WHEN 3 THEN {(short)MarketplacePostKind.Advertisement} ELSE {(short)MarketplacePostKind.Listing} END,
                   CASE WHEN n % 5 = 0 THEN {(short)MarketplacePostStatus.Paused} ELSE {(short)MarketplacePostStatus.Active} END,
                   'Post ' || n,
                   CASE WHEN n % 4 = 3 THEN NULL ELSE 100 + n % 900 END,
                   CASE WHEN n % 4 = 1 THEN {(short)MarketplaceTradeType.Wholesale} ELSE {(short)MarketplaceTradeType.Retail} END,
                   CASE WHEN n % 4 = 1 THEN 10 END,
                   CASE WHEN n % 4 = 0 THEN {(short)MarketplaceItemCondition.New} END,
                   CASE WHEN n % 4 = 0 THEN 5 WHEN n % 4 = 2 THEN 20 END,
                   '{district}', now() - n * interval '1 minute', false,
                   CASE WHEN n % 4 IN (2, 3) THEN now() - interval '1 hour' END,
                   CASE WHEN n % 4 IN (2, 3) THEN now() + interval '5 days' END
            FROM generate_series(1, {Businesses * PostsEach + BigSellerPosts}) AS n;

            INSERT INTO marketplace_post_variants (id, post_id, colour, size, stock, sort_order, created_date, is_deleted)
            SELECT gen_random_uuid(), p.id, c.colour, 'M', 3, c.ord, now(), false
            FROM (SELECT id FROM marketplace_posts WHERE owner_user_id = '{BigSeller}' AND condition = 1 LIMIT 500) p
            CROSS JOIN (VALUES ('Red', 0), ('Blue', 1), ('Green', 2)) AS c(colour, ord);

            ANALYZE marketplace_posts;
            ANALYZE marketplace_post_variants;
            """;
        await db.Database.ExecuteSqlRawAsync(seed);
    }

}
