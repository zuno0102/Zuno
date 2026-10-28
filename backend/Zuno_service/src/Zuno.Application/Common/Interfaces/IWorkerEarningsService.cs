using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// One worker's earnings and work record, gathered from both routes onto paid work.
/// </summary>
/// <remarks>
/// Exists so the rule lives once. The worker's profile and their dashboard both show "jobs
/// completed" and "total earned", and before this they were computed separately in each handler —
/// from the hiring-post side only, so a worker put on an order by hand read as having done nothing.
/// Computed on read rather than denormalised, matching <see cref="IBusinessTrustService"/>; there
/// are no counters on <c>WorkerProfile</c> to keep in step.
/// </remarks>
public interface IWorkerEarningsService
{
    /// <summary>What this worker has earned, is owed, and has finished.</summary>
    Task<WorkerEarningsRollup> GetAsync(
        Guid workerProfileId,
        CancellationToken cancellationToken = default);
}
