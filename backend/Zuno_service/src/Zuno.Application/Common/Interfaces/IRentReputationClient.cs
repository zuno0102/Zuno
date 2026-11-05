namespace Zuno.Application.Common.Interfaces;

/// <summary>One business's record in Zuno Rent, as the Rent API reports it.</summary>
/// <param name="OwnerUserId">The business owner's user id — the same account in Service and Rent.</param>
/// <param name="RatingSum">All the stars customers gave its Rent orders, added together.</param>
/// <param name="RatingCount">How many Rent orders were rated.</param>
/// <param name="SuccessfulOrders">Rent orders returned and paid in full.</param>
public sealed record RentReputation(Guid OwnerUserId, decimal RatingSum, int RatingCount, int SuccessfulOrders);

/// <summary>Reads every business's Rent record from the Rent API, which owns those figures.</summary>
public interface IRentReputationClient
{
    /// <summary>
    /// Every business that has a Rent record, or null when the figures could not be read — the Rent API
    /// is not configured, asleep past the time-out, or answered with something unusable. Null means
    /// "unknown", never "zero": the caller keeps what it already has.
    /// </summary>
    Task<IReadOnlyList<RentReputation>?> GetAllAsync(CancellationToken cancellationToken);
}
