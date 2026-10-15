namespace Zuno.Domain.Enums;

/// <summary>
/// A batch pays one job's whole crew from a single collection. The two legs are tracked separately
/// because money can be taken from the business and still fail to reach a worker — and the two need
/// very different responses.
/// </summary>
public enum PayoutBatchStatus : short
{
    /// <summary>Created; the business has not paid yet.</summary>
    AwaitingCollection = 1,

    /// <summary>The business's money is in. Disbursing to each worker.</summary>
    Disbursing = 2,

    /// <summary>Every worker in the batch was paid.</summary>
    Completed = 3,

    /// <summary>Collected, but at least one worker could not be paid. Retryable per item.</summary>
    PartiallyFailed = 4,

    /// <summary>The business never completed the payment. Nothing was disbursed.</summary>
    Abandoned = 5,
}
