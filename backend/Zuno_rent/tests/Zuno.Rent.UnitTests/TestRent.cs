using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Infrastructure.Persistence;
using Zuno.Rent.Infrastructure.Persistence.Seed;

namespace Zuno.Rent.UnitTests;

/// <summary>A fresh in-memory Rent database with the seeded catalogue and districts, and the people using it.</summary>
internal sealed class TestRent : IDisposable
{
    public static readonly Guid OwnerA = Guid.NewGuid();
    public static readonly Guid OwnerB = Guid.NewGuid();

    public static readonly Guid Ernakulam = LocationSeedData.DistrictId("Kerala", "Ernakulam");
    public static readonly Guid Thrissur = LocationSeedData.DistrictId("Kerala", "Thrissur");

    public static readonly Guid CuttingMachine = RentalCategorySeedData.SubCategoryId(6, 1);
    public static readonly Guid PlasticChairs = RentalCategorySeedData.SubCategoryId(1, 1);

    private readonly string _databaseName = Guid.NewGuid().ToString();

    public TestRent(Guid? userId = null)
    {
        User = new FakeCurrentUser { UserId = userId ?? OwnerA };
        Db = NewContext();
        Db.Database.EnsureCreated();
    }

    /// <summary>A second connection to the same data, as a request running at the same time has.</summary>
    public RentDbContext NewContext() => new(new DbContextOptionsBuilder<RentDbContext>()
        .UseInMemoryDatabase(_databaseName)
        .AddInterceptors(new AuditInterceptor(User, TimeProvider.System))
        .Options);

    public RentDbContext Db { get; }

    public FakeCurrentUser User { get; }

    public FakeMediaStorage Storage { get; } = new();

    public IOptions<RentSettings> Settings { get; } = Options.Create(new RentSettings());

    public SaveRentalItemHandlers SaveHandlers => new(User, Db, Settings);

    public RentalItemMediaHandlers MediaHandlers => new(User, Db, Storage);

    public static CreateRentalItemCommand Machine(Action<CreateRentalItemCommand>? change = null)
    {
        var command = new CreateRentalItemCommand
        {
            RentalCategoryId = RentalCategorySeedData.ToolsMachines,
            RentalSubCategoryId = CuttingMachine,
            Name = "Cutting machine",
            Description = "Heavy duty",
            PriceType = "Daily",
            Price = 500,
            QuantityOwned = 1,
            DistrictIds = [Ernakulam],
        };
        change?.Invoke(command);
        return command;
    }

    public static UpdateRentalItemCommand Edit(Guid id, Action<UpdateRentalItemCommand>? change = null)
    {
        var command = new UpdateRentalItemCommand
        {
            Id = id,
            RentalCategoryId = RentalCategorySeedData.ToolsMachines,
            RentalSubCategoryId = CuttingMachine,
            Name = "Cutting machine",
            PriceType = "Daily",
            Price = 500,
            QuantityOwned = 1,
            DistrictIds = [Ernakulam],
        };
        change?.Invoke(command);
        return command;
    }

    /// <summary>The mobile test customers book with.</summary>
    public const string Phone = "9876543210";

    /// <summary>Marks each customer as having verified <see cref="Phone"/>, as every app booking needs.</summary>
    public TestRent WithVerifiedPhone(params Guid[] customers)
    {
        foreach (var customer in customers)
        {
            Db.RentalPhoneVerifications.Add(new RentalPhoneVerification
            {
                CustomerUserId = customer,
                Phone = Phone,
                VerifiedAt = DateTimeOffset.UtcNow,
            });
        }

        Db.SaveChanges();
        Db.ChangeTracker.Clear();
        return this;
    }

    /// <summary>Acts as someone else on the same data, as a second request would.</summary>
    public TestRent As(Guid userId)
    {
        User.UserId = userId;
        Db.ChangeTracker.Clear();
        return this;
    }

    public void Dispose() => Db.Dispose();
}

internal sealed class FakeCurrentUser : ICurrentUser
{
    public Guid? UserId { get; set; }
}

internal sealed class FakeMediaStorage : IRentMediaStorage
{
    private int _counter;

    public List<string> Saved { get; } = [];

    public List<string> Deleted { get; } = [];

    public Task<string> SaveImageAsync(Guid rentalItemId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        Task.FromResult(Record($"/uploads/rentals/{rentalItemId}/image-{slot}-{++_counter:x12}{fileExtension}"));

    public Task<string> SaveVideoAsync(Guid rentalItemId, Stream content, string fileExtension, CancellationToken cancellationToken) =>
        Task.FromResult(Record($"/uploads/rentals/{rentalItemId}/video-{++_counter:x12}{fileExtension}"));

    public void Delete(string publicUrl) => Deleted.Add(publicUrl);

    private string Record(string url)
    {
        Saved.Add(url);
        return url;
    }
}

/// <summary>
/// A payment gateway that raises numbered orders and accepts a payment only with the signature
/// "good" — so tests prove a bad or missing signature is refused.
/// </summary>
internal sealed class FakePaymentGateway : IRentPaymentGateway
{
    public bool IsReady { get; set; } = true;

    public bool IsSimulated { get; set; }

    public string KeyId => "rzp_test_key";

    public List<(decimal Amount, string Receipt)> Orders { get; } = [];

    public Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken)
    {
        Orders.Add((amount, receipt));
        return Task.FromResult($"order_{Orders.Count}");
    }

    public bool VerifySignature(string providerOrderId, string paymentId, string signature) => signature == "good";

    /// <summary>Payments the gateway holds as captured, by its order id — money taken in a UPI app.</summary>
    public Dictionary<string, string> Captured { get; } = [];

    /// <summary>The gateway does not answer (network, outage).</summary>
    public bool Unreachable { get; set; }

    public List<string> Asked { get; } = [];

    public Task<string?> FindCapturedPaymentAsync(string providerOrderId, CancellationToken cancellationToken)
    {
        Asked.Add(providerOrderId);
        if (Unreachable)
        {
            throw new HttpRequestException("Razorpay did not answer.");
        }

        return Task.FromResult(Captured.TryGetValue(providerOrderId, out var paymentId) ? paymentId : null);
    }
}
