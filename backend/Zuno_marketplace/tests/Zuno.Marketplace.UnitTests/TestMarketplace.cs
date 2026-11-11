using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Zuno.Marketplace.Application.Admin;
using Zuno.Marketplace.Application.Categories;
using Zuno.Marketplace.Application.Common;
using Zuno.Marketplace.Application.Posts;
using Zuno.Marketplace.Domain.Entities;
using Zuno.Marketplace.Infrastructure.Persistence;
using Zuno.Marketplace.Infrastructure.Persistence.Seed;

namespace Zuno.Marketplace.UnitTests;

/// <summary>A fresh in-memory Marketplace database with the seeded catalogue, plan and districts, and the people using it.</summary>
internal sealed class TestMarketplace : IDisposable
{
    public static readonly Guid OwnerA = Guid.NewGuid();
    public static readonly Guid OwnerB = Guid.NewGuid();

    public static readonly Guid Kanyakumari = LocationSeedData.DistrictId("Tamil Nadu", "Kanyakumari");

    private readonly string _databaseName = Guid.NewGuid().ToString();
    private readonly MemoryCache _cache = new(new MemoryCacheOptions());

    public TestMarketplace(Guid? userId = null)
    {
        User = new FakeCurrentUser { UserId = userId ?? OwnerA };
        Db = NewContext();
        Db.Database.EnsureCreated();
    }

    public MarketplaceDbContext NewContext() => new(new DbContextOptionsBuilder<MarketplaceDbContext>()
        .UseInMemoryDatabase(_databaseName)
        .AddInterceptors(new AuditInterceptor(User, Clock))
        .Options);

    public MarketplaceDbContext Db { get; }

    public FakeCurrentUser User { get; }

    public FixedClock Clock { get; } = new(new DateTimeOffset(2026, 11, 11, 12, 0, 0, TimeSpan.Zero));

    public DateTimeOffset Now => Clock.GetUtcNow();

    public FakeMediaStorage Storage { get; } = new();

    public MarketplaceSettings Limits { get; } = new();

    public IOptions<MarketplaceSettings> Settings => Options.Create(Limits);

    public MarketplaceReference Reference => new(Db, _cache, Settings);

    public SaveMarketplacePostHandlers SaveHandlers => new(User, Db, Reference, Clock, Settings);

    public ManageMarketplacePostHandlers ManageHandlers => new(User, Db, Storage, Reference, Clock);

    public MarketplacePostQueryHandlers QueryHandlers => new(User, Db, Reference, Clock, Settings);

    public MarketplaceCatalogHandlers CatalogHandlers => new(Db, Reference, Settings);

    public MarketplaceCategoryAdminHandlers AdminHandlers => new(Db, Reference);

    public static CreateMarketplacePostCommand Car(Action<CreateMarketplacePostCommand>? change = null)
    {
        var command = new CreateMarketplacePostCommand
        {
            CategoryId = MarketplaceCatalogSeedData.Vehicles,
            Title = "Swift VXi 2019",
            Price = 420_000m,
            DistrictId = Kanyakumari,
            Area = "Marthandam",
            Attributes = new() { ["brand"] = "Maruti", ["model_year"] = "2019", ["km_driven"] = "48000", ["fuel"] = "Petrol" },
        };
        change?.Invoke(command);
        return command;
    }

    public CreateMarketplacePostCommand Biryani(Action<CreateMarketplacePostCommand>? change = null)
    {
        var command = new CreateMarketplacePostCommand
        {
            CategoryId = MarketplaceCatalogSeedData.FoodOffers,
            Title = "Veg biryani",
            Price = 99m,
            OriginalPrice = 180m,
            PriceUnit = "plate",
            Quantity = 20,
            StartsAt = Now,
            EndsAt = Now.AddHours(2),
            DistrictId = Kanyakumari,
            Attributes = new() { ["food_type"] = "Veg" },
        };
        change?.Invoke(command);
        return command;
    }

    public CreateMarketplacePostCommand AadiSale(Action<CreateMarketplacePostCommand>? change = null)
    {
        var command = new CreateMarketplacePostCommand
        {
            CategoryId = MarketplaceCatalogSeedData.EventsSales,
            Title = "Aadi sale 50% off",
            StartsAt = Now,
            EndsAt = Now.AddDays(30),
            ContactPhone = "9876543210",
            DistrictId = Kanyakumari,
            Attributes = new() { ["ad_type"] = "Sale / offer" },
        };
        change?.Invoke(command);
        return command;
    }

    public static CreateMarketplacePostCommand Bananas(Action<CreateMarketplacePostCommand>? change = null)
    {
        var command = new CreateMarketplacePostCommand
        {
            CategoryId = MarketplaceCatalogSeedData.FarmWholesale,
            Title = "Nendran banana",
            Price = 45m,
            PriceUnit = "kg",
            TradeType = "Wholesale",
            MinOrderQuantity = 100,
            Quantity = 2000,
            DistrictId = Kanyakumari,
            Attributes = new() { ["produce_type"] = "Fruits" },
        };
        change?.Invoke(command);
        return command;
    }

    /// <summary>Saves a post straight into the store, bypassing the plan limit — for setting up a scene.</summary>
    public MarketplacePost Seed(Action<MarketplacePost>? change = null)
    {
        var post = new MarketplacePost
        {
            OwnerUserId = User.UserId ?? OwnerA,
            CategoryId = MarketplaceCatalogSeedData.Vehicles,
            Kind = Domain.Enums.MarketplacePostKind.Listing,
            Title = "Seeded post",
            Price = 100m,
            DistrictId = Kanyakumari,
        };
        change?.Invoke(post);
        Db.Posts.Add(post);
        Db.SaveChanges();
        Db.ChangeTracker.Clear();
        return post;
    }

    /// <summary>Acts as someone else on the same data, as a second request would.</summary>
    public TestMarketplace As(Guid userId)
    {
        User.UserId = userId;
        Db.ChangeTracker.Clear();
        return this;
    }

    public void Dispose()
    {
        Db.Dispose();
        _cache.Dispose();
    }
}

internal sealed class FakeCurrentUser : ICurrentUser
{
    public Guid? UserId { get; set; }
}

/// <summary>A clock the test sets, so time rules are checked at exact moments.</summary>
internal sealed class FixedClock(DateTimeOffset now) : TimeProvider
{
    public DateTimeOffset Current { get; set; } = now;

    public override DateTimeOffset GetUtcNow() => Current;
}

internal sealed class FakeMediaStorage : IMarketplaceMediaStorage
{
    private int _counter;

    public List<string> Saved { get; } = [];

    public List<string> Deleted { get; } = [];

    public Task<string> SaveImageAsync(Guid postId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken)
    {
        var url = $"/uploads/marketplace/{postId}/image-{slot}-{++_counter:x12}{fileExtension}";
        Saved.Add(url);
        return Task.FromResult(url);
    }

    public void Delete(string publicUrl) => Deleted.Add(publicUrl);
}

internal sealed class FakeServiceDirectory : IServiceDirectory
{
    public ServiceBusiness? Business { get; set; } = new("shajil shajil", null, IsVerified: true);

    public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken) => Task.FromResult(Business);
}
