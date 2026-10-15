namespace Zuno.Domain.Enums;

/// <summary>
/// Hiring is a two-sided handshake: the business offers, then the worker accepts. A slot is
/// only really taken at <see cref="Accepted"/> — everything before that is still provisional,
/// so the vacancy stays open and the post stays visible to other workers.
/// </summary>
public enum HiringPostApplicationStatus : short
{
    /// <summary>The worker applied and is waiting on the business.</summary>
    Applied = 1,

    /// <summary>
    /// The business approved this worker. The offer now sits with the worker, who has not
    /// answered yet — this does NOT fill the vacancy.
    /// </summary>
    Confirmed = 2,

    /// <summary>The business turned the applicant down.</summary>
    Rejected = 3,

    /// <summary>The worker accepted the offer. This is the only status that fills a slot.</summary>
    Accepted = 4,

    /// <summary>The worker turned the offer down, releasing the slot back to the vacancy.</summary>
    Declined = 5,
}
