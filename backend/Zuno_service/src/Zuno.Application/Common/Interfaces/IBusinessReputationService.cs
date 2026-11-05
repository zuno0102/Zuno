namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Keeps a business's denormalised standing — completed jobs, both rating averages, open disputes
/// and level — in step with what has actually happened.
/// </summary>
/// <remarks>
/// Called after anything that can move those figures: a job settling, a dispute being raised or
/// resolved, a review landing. It recomputes from the underlying rows rather than incrementing a
/// counter, so a figure that has drifted repairs itself on the next call instead of staying wrong
/// forever.
/// </remarks>
public interface IBusinessReputationService
{
    /// <summary>
    /// Recalculates every stored figure for one business and saves it.
    /// </summary>
    /// <remarks>
    /// <strong>Call this after your own SaveChanges, never before.</strong> The figures are counted
    /// in the database, so a change still sitting unsaved in the change tracker is invisible to
    /// them — calling first would credit the payment that finished a job to some later
    /// recalculation that may never come.
    /// <para>
    /// It saves the profile itself, in a second commit. That leaves a moment where the work is
    /// recorded and the standing is not, which is harmless: nothing here increments, so the next
    /// call recomputes the truth whatever happened in between.
    /// </para>
    /// </remarks>
    Task RecalculateAndSaveAsync(Guid businessOwnerProfileId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Recalculates every stored figure for a batch of tracked profiles, without saving — the caller saves
    /// the batch once. A handful of grouped queries serve the whole batch, however large.
    /// </summary>
    Task RecalculateAsync(IReadOnlyList<Domain.Entities.BusinessOwnerProfile> profiles, CancellationToken cancellationToken = default);

    /// <summary>
    /// Recounts one service's rating total and count from the ratings table and saves them. Call it after
    /// the rating is saved, for the same reason as <see cref="RecalculateAndSaveAsync"/>.
    /// </summary>
    Task RecalculateServiceRatingAsync(Guid businessServiceId, CancellationToken cancellationToken = default);
}
