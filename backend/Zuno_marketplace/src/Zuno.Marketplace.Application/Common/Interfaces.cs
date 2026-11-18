using Microsoft.EntityFrameworkCore;
using Zuno.Marketplace.Domain.Entities;

namespace Zuno.Marketplace.Application.Common;

/// <summary>The Marketplace database — its own, apart from the Service and Rent databases.</summary>
public interface IMarketplaceDbContext
{
    public DbSet<MarketplaceCategory> Categories { get; }

    public DbSet<MarketplaceSubCategory> SubCategories { get; }

    public DbSet<MarketplaceCategoryField> CategoryFields { get; }

    public DbSet<MarketplacePost> Posts { get; }

    public DbSet<MarketplacePostMedia> PostMedia { get; }

    public DbSet<MarketplacePostVariant> PostVariants { get; }

    public DbSet<MarketplaceBusiness> Businesses { get; }

    public DbSet<MarketplacePlan> Plans { get; }

    public DbSet<MarketplaceBusinessPlan> BusinessPlans { get; }

    public DbSet<MarketplaceTradeModeOption> TradeModes { get; }

    public DbSet<MarketplaceItemConditionOption> ItemConditions { get; }

    public DbSet<MarketplacePostKindOption> PostKinds { get; }

    public DbSet<MarketplacePostStatusOption> PostStatuses { get; }

    public DbSet<MarketplacePostTransition> PostTransitions { get; }

    public DbSet<MarketplaceOrder> Orders { get; }

    public DbSet<MarketplaceOrderEvent> OrderEvents { get; }

    public DbSet<MarketplaceOrderStatusOption> OrderStatuses { get; }

    public DbSet<MarketplaceOrderTransition> OrderTransitions { get; }

    public DbSet<MarketplaceCourier> Couriers { get; }

    public DbSet<MarketplacePaymentMethodOption> PaymentMethods { get; }

    public DbSet<MarketplaceB2BRequest> B2BRequests { get; }

    public DbSet<MarketplaceB2BRequestStatusOption> B2BRequestStatuses { get; }

    public DbSet<RefState> States { get; }

    public DbSet<RefDistrict> Districts { get; }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Runs [work] in one transaction holding a lock for this business, so two saves at once cannot
    /// both pass the plan's post limit: the second waits, then counts the first one's post.
    /// </summary>
    public Task<T> WithOwnerLockAsync<T>(Guid ownerUserId, Func<Task<T>> work, CancellationToken cancellationToken);
}

/// <summary>
/// The Service API, asked with the caller's own login: the business's name and verification. The
/// token carries only an id, so names come from where accounts live — never from what the app sends.
/// </summary>
public interface IServiceDirectory
{
    /// <summary>The signed-in business's profile; null when there is none or the API cannot be reached.</summary>
    public Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken);

    /// <summary>The signed-in person's name and mobile; null when the Service API cannot be reached.</summary>
    public Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken);
}

public record ServiceBusiness(string Name, string? LogoUrl, bool IsVerified);

public record ServicePerson(string Name, string? Phone);

/// <summary>
/// Takes a customer's online payment for an order — collected by Zuno — and gives it back when the
/// order is cancelled. The app only reports a payment; the gateway's signature, made with a secret
/// only the server holds, is what proves it.
/// </summary>
/// <remarks>A simulated gateway, for tests and phones without a merchant account, is allowed in Development only.</remarks>
public interface IMarketplacePaymentGateway
{
    /// <summary>Whether online payment can be taken at all: keys set, or simulated in Development.</summary>
    public bool IsReady { get; }

    /// <summary>No real money moves: the app skips the payment window and the signature is not checked.</summary>
    public bool IsSimulated { get; }

    /// <summary>The public key the app opens the payment window with.</summary>
    public string KeyId { get; }

    /// <summary>Raises a gateway order for <paramref name="amount"/>. The same <paramref name="receipt"/> returns the same order.</summary>
    public Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken);

    /// <summary>Whether the payment really completed against this gateway order.</summary>
    public bool VerifySignature(string providerOrderId, string paymentId, string signature);

    /// <summary>
    /// Asks the gateway whether this order was paid, for a customer whose app closed before reporting
    /// back. The paid payment's id, or null. Throws when the gateway could not be asked.
    /// </summary>
    public Task<string?> FindCapturedPaymentAsync(string providerOrderId, CancellationToken cancellationToken);

    /// <summary>Gives a payment back in full. Returns the refund's id; throws when the gateway refuses.</summary>
    public Task<string> RefundAsync(string paymentId, decimal amount, CancellationToken cancellationToken);
}

/// <summary>Who is calling, read from the shared login's token.</summary>
public interface ICurrentUser
{
    public Guid? UserId { get; }
}

/// <summary>Where a post's photos are kept.</summary>
public interface IMarketplaceMediaStorage
{
    /// <summary>
    /// Saves a photo into <paramref name="slot"/> — of the colour / size <paramref name="variantId"/>, or
    /// of the post itself when null — replacing what was there. Returns its public URL.
    /// </summary>
    public Task<string> SaveImageAsync(
        Guid postId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken, Guid? variantId = null);

    /// <summary>Saves the photo of an order's courier receipt, replacing an earlier one. Returns its public URL.</summary>
    public Task<string> SaveOrderReceiptAsync(Guid orderId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Deletes the file behind a URL this storage returned, if it is still there.</summary>
    public void Delete(string publicUrl);
}
