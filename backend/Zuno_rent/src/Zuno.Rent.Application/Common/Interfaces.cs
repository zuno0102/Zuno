using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Domain.Entities;

namespace Zuno.Rent.Application.Common;

/// <summary>The Rent database — its own, apart from the Service database.</summary>
public interface IRentDbContext
{
    DbSet<RentalItem> RentalItems { get; }

    DbSet<RentalItemMedia> RentalItemMedia { get; }

    DbSet<RentalItemDistrict> RentalItemDistricts { get; }

    DbSet<RentalItemQuestion> RentalItemQuestions { get; }

    DbSet<RentalPriceTypeOption> RentalPriceTypes { get; }

    DbSet<RentalOrder> RentalOrders { get; }

    DbSet<RentalOrderStatusOption> RentalOrderStatuses { get; }

    DbSet<RentalOrderTransition> RentalOrderTransitions { get; }

    DbSet<RentalOrderMessage> RentalOrderMessages { get; }

    DbSet<RentalOrderEvent> RentalOrderEvents { get; }

    DbSet<RentalOrderEventKindOption> RentalOrderEventKinds { get; }

    DbSet<RentalBusiness> RentalBusinesses { get; }

    DbSet<RentalOrderAnswer> RentalOrderAnswers { get; }

    DbSet<RentalHomeSection> RentalHomeSections { get; }

    DbSet<RentalOrderPayment> RentalOrderPayments { get; }

    DbSet<RentalPaymentCheckout> RentalPaymentCheckouts { get; }

    DbSet<RentalAdvanceTypeOption> RentalAdvanceTypes { get; }

    DbSet<RentalPaymentMethodOption> RentalPaymentMethods { get; }

    DbSet<RentalPaymentStatusOption> RentalPaymentStatuses { get; }

    DbSet<RentalRefundModeOption> RentalRefundModes { get; }

    DbSet<RentalCancelChargeTypeOption> RentalCancelChargeTypes { get; }

    DbSet<RentalCategory> RentalCategories { get; }

    DbSet<RentalSubCategory> RentalSubCategories { get; }

    DbSet<RefDistrict> Districts { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Runs [work] in one transaction holding a lock on the item's row, so two orders for the last
    /// pieces cannot both pass the availability check: the second waits, then sees the first.
    /// </summary>
    Task<T> WithItemLockAsync<T>(Guid rentalItemId, Func<Task<T>> work, CancellationToken cancellationToken);
}

/// <summary>
/// The Service API, asked with the caller's own login: who they are and, for a business, its name and
/// verification. The token carries only an id, so names come from where accounts live — never from
/// what the app sends.
/// </summary>
public interface IServiceDirectory
{
    /// <summary>The signed-in person's name and phone; null when the Service API cannot be reached.</summary>
    Task<ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken);

    /// <summary>The signed-in business's profile; null when there is none or the API cannot be reached.</summary>
    Task<ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken);
}

public record ServicePerson(string Name, string? Phone);

/// <summary>The business's Service profile. <paramref name="UpiId"/> is null until the business adds one.</summary>
public record ServiceBusiness(string Name, string? LogoUrl, bool IsVerified, string? UpiId = null);

/// <summary>Who is calling, read from the shared login's token.</summary>
public interface ICurrentUser
{
    Guid? UserId { get; }
}

/// <summary>Where a rent item's photos and video are kept.</summary>
public interface IRentMediaStorage
{
    /// <summary>Saves a photo into <paramref name="slot"/>, replacing what was there. Returns its public URL.</summary>
    Task<string> SaveImageAsync(
        Guid rentalItemId, int slot, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Saves the item's video, replacing any earlier one. Returns its public URL.</summary>
    Task<string> SaveVideoAsync(
        Guid rentalItemId, Stream content, string fileExtension, CancellationToken cancellationToken);

    /// <summary>Deletes the file behind a URL this storage returned, if it is still there.</summary>
    void Delete(string publicUrl);
}

/// <summary>
/// Takes a customer's online payment: raises an order to pay against, and checks the gateway's
/// signature on a finished payment. The app only reports a payment; the signature, made with a secret
/// only the server holds, is what proves it.
/// </summary>
/// <remarks>
/// An interface so the flow runs in tests and on a phone without a merchant account: a simulated
/// gateway is allowed in Development only, and is refused anywhere else when the API starts.
/// </remarks>
public interface IRentPaymentGateway
{
    /// <summary>Whether online payment can be taken at all — keys set, or simulated in Development.</summary>
    bool IsReady { get; }

    /// <summary>No real money moves: the app skips the payment window and the signature is not checked.</summary>
    bool IsSimulated { get; }

    /// <summary>The public key the app opens the payment window with.</summary>
    string KeyId { get; }

    /// <summary>Raises an order for <paramref name="amount"/>. The same <paramref name="receipt"/> returns the same order.</summary>
    Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken);

    /// <summary>Whether the payment really completed against this order.</summary>
    bool VerifySignature(string providerOrderId, string paymentId, string signature);

    /// <summary>
    /// Asks the gateway itself whether this order was paid — for a customer whose UPI app took the money
    /// but whose app closed before reporting back. The paid payment's id, or null when there is none.
    /// Throws when the gateway could not be asked — that is not "not paid".
    /// </summary>
    Task<string?> FindCapturedPaymentAsync(string providerOrderId, CancellationToken cancellationToken);
}
