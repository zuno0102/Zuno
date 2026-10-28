using Zuno.Domain.Enums;

namespace Zuno.Domain.ValueObjects;

/// <summary>
/// What one order's crew is owed, gathered from every hiring post raised against it.
/// </summary>
/// <remarks>
/// Counted over <em>payees</em> — the accepted workers — rather than over the posts they came from.
/// A post with nobody hired is deliberately never "fully settled", so an order carrying one paid
/// post alongside one nobody accepted would read as owing money for ever if the posts were
/// combined instead of their crews.
/// </remarks>
/// <param name="PayeeCount">Accepted workers across every linked post.</param>
/// <param name="PaidPayeeCount">How many of them have been paid.</param>
/// <param name="DisputedPayeeCount">How many say a payment never arrived.</param>
/// <param name="TotalPayable">The whole wage bill for the order.</param>
/// <param name="OutstandingAmount">What is still owed.</param>
public readonly record struct BookingWageRollup(
    int PayeeCount,
    int PaidPayeeCount,
    int DisputedPayeeCount,
    decimal TotalPayable,
    decimal OutstandingAmount)
{
    /// <summary>An order with no in-app wages at all.</summary>
    public static BookingWageRollup None => new(0, 0, 0, 0m, 0m);

    /// <summary>Checked in order: nobody owed, then disputed, then owing, then square.</summary>
    public BookingWageStatus Status => this switch
    {
        { PayeeCount: 0 } => BookingWageStatus.NoWagesThroughZuno,
        { DisputedPayeeCount: > 0 } => BookingWageStatus.Disputed,
        _ when PaidPayeeCount < PayeeCount => BookingWageStatus.Outstanding,
        _ => BookingWageStatus.Settled,
    };

    /// <summary>
    /// Nobody is waiting on money — either everyone was paid, or nobody was owed.
    /// </summary>
    /// <remarks>
    /// The half of "this order is finished" that the work track cannot answer. Kept as one property
    /// so the screens and the completed-job count cannot disagree about what square means.
    /// </remarks>
    public bool IsWageClear => Status
        is BookingWageStatus.Settled
        or BookingWageStatus.NoWagesThroughZuno;
}
