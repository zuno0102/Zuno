namespace Zuno.Domain.Enums;

/// <summary>
/// Where one worker's wage for one job has got to. Distinct from the job's own progress: work can
/// be finished long before anyone is paid, and being paid is what actually closes a hiring out.
/// </summary>
public enum PaymentStatus : short
{
    /// <summary>Owed, nothing attempted yet.</summary>
    Unpaid = 1,

    /// <summary>Sent to the payout provider; waiting on its webhook to say whether it landed.</summary>
    Processing = 2,

    /// <summary>
    /// Settled by the provider, or confirmed received by the worker when paid outside the app.
    /// The only status that counts toward a business's record.
    /// </summary>
    Paid = 3,

    /// <summary>The provider rejected or reversed it. Retryable without re-collecting from the business.</summary>
    Failed = 4,

    /// <summary>
    /// The business says it paid and the worker says otherwise. Held open until an admin resolves
    /// it, and the signal the whole trust score rests on.
    /// </summary>
    Disputed = 5,

    /// <summary>Paid outside the app; the worker has yet to confirm it arrived.</summary>
    AwaitingWorkerConfirmation = 6,
}
