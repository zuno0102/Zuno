namespace Zuno.Domain.Enums;

/// <summary>
/// Where a piece of work stands as people read it: one value per status chip and filter.
/// </summary>
/// <remarks>
/// Only what the code decides on. How each stage is named, coloured, ordered and which screens show
/// it live in the <c>order_stages</c> table (<see cref="Entities.OrderStageDefinition"/>), so they can
/// change without a new app. Persisted as smallint — never renumber.
/// </remarks>
public enum OrderStage : short
{
    /// <summary>A customer's request the business has not accepted yet.</summary>
    Active = 1,

    /// <summary>Accepted (or, for an own event, planned) and not started.</summary>
    Confirmed = 2,

    /// <summary>Work under way.</summary>
    InProgress = 3,

    /// <summary>Work done, somebody still to be paid.</summary>
    AwaitingPayment = 4,

    /// <summary>Done and nobody owed.</summary>
    Completed = 5,

    Cancelled = 6,
}
