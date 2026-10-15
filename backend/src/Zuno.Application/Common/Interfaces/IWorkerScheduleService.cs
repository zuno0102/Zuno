namespace Zuno.Application.Common.Interfaces;

/// <summary>Why a job cannot be taken on.</summary>
public enum WorkerScheduleConflictKind
{
    /// <summary>The two jobs run at the same time.</summary>
    Overlap,

    /// <summary>
    /// They do not overlap, but there is not enough time between them to get from one venue
    /// to the other.
    /// </summary>
    TooTight,

    /// <summary>
    /// The worker is part-way through a job that nobody has marked finished.
    /// </summary>
    /// <remarks>
    /// Checked whatever the dates say. Work that has started and not been closed has no reliable
    /// end — a two-hour booking can run five — so the clock cannot tell you the worker is free.
    /// Holding them until someone says the job is done protects the worker from being promised
    /// to a second business while still standing in the first one's kitchen, and gives them a
    /// reason to see the finish recorded.
    /// </remarks>
    Unfinished,
}

/// <summary>One job already in a worker's diary that stands in the way of another.</summary>
/// <param name="Kind">Whether the jobs collide outright or merely leave no travel time.</param>
/// <param name="Source">"hiring post" or "booking" — used to phrase the message.</param>
/// <param name="Title">The job's name, so the clash is recognisable rather than an id.</param>
/// <param name="StartsAt">Start of the clashing job.</param>
/// <param name="EndsAt">End of the clashing job.</param>
/// <param name="GapMinutes">
/// Minutes between the two jobs. Zero or negative when they overlap.
/// </param>
public record WorkerScheduleConflict(
    WorkerScheduleConflictKind Kind,
    string Source,
    string Title,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    int GapMinutes);

/// <summary>A block of time in a worker's diary, whichever module booked it.</summary>
/// <param name="WorkerProfileId">Whose diary this belongs to.</param>
/// <param name="StartsAt">When it begins.</param>
/// <param name="EndsAt">
/// When it ends. Computed, not stored — a booking has no duration column, so this rests on the
/// package's estimate, then the service's, then a two-hour default.
/// </param>
/// <remarks>
/// Times only, deliberately. A worker's diary spans every business they serve, so anything
/// naming the work would show one business another's customers — and a caller that only needs
/// to know whether the worker is free has no use for the name anyway.
/// </remarks>
public record WorkerCommitment(
    Guid WorkerProfileId,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt);

/// <summary>A job that should have finished by now but has not been marked done.</summary>
/// <param name="Title">The job that is running late.</param>
/// <param name="DueToEndAt">When it was scheduled to finish.</param>
/// <param name="MinutesLate">How far past that it now is.</param>
public record WorkerOverrun(
    string Title,
    DateTimeOffset DueToEndAt,
    int MinutesLate,
    Guid? HiringPostId);

/// <summary>
/// Answers whether a worker is free for a window, and whether their current work is running late.
/// </summary>
/// <remarks>
/// Deliberately spans both hiring posts and bookings. A worker hired through a hiring post is
/// just as unavailable as one assigned to a booking, and checking only one source would let the
/// same person be promised to two jobs at the same hour through different doors.
/// </remarks>
public interface IWorkerScheduleService
{
    /// <summary>
    /// The gap a worker needs between two jobs to travel between venues. Without it, work
    /// finishing at 15:00 and work starting at 15:00 look compatible, which they never are.
    /// </summary>
    /// <remarks>
    /// A worker must <em>exceed</em> this, not merely match it: with a 30-minute buffer, work
    /// ending at 11:00 frees them from 11:31, and 11:30 is still refused.
    /// </remarks>
    int TravelBufferMinutes { get; }

    /// <summary>
    /// Returns the first job standing in the way, or null when the worker is free for the
    /// window with enough time either side to get there.
    /// </summary>
    /// <param name="excludeHiringPostId">
    /// The hiring post being accepted or offered, so it never counts as a clash with itself.
    /// </param>
    /// <param name="excludeBookingId">The booking being assigned, for the same reason.</param>
    /// <summary>
    /// Everything holding these workers, soonest first — for showing a diary, or for deciding
    /// whether someone is free, rather than judging one window against it.
    /// </summary>
    /// <remarks>
    /// The single source for both. A screen that says "already booked" and a screen that lists
    /// the dates behind it must agree, and they can only be sure of that by counting the same
    /// commitments; the availability badge and the schedule are built from this one call.
    /// <para>
    /// Also the same set <see cref="FindConflictAsync"/> judges against, so what a business is
    /// shown can never contradict the check that refuses an assignment.
    /// </para>
    /// <para>
    /// Nothing is collapsed: two jobs at the same hour are two entries, because that is what
    /// they are, and merging them would hide the double-booking worth seeing.
    /// </para>
    /// </remarks>
    Task<IReadOnlyList<WorkerCommitment>> GetCommitmentsAsync(
        IReadOnlyCollection<Guid> workerProfileIds,
        CancellationToken cancellationToken = default);

    Task<WorkerScheduleConflict?> FindConflictAsync(
        Guid workerProfileId,
        DateTimeOffset startsAt,
        DateTimeOffset endsAt,
        Guid? excludeHiringPostId = null,
        Guid? excludeBookingId = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// For each of the given workers, the job that was due to finish before now and has not been
    /// marked complete — the reason they may not make it to whatever they are booked on next.
    /// Workers whose work is on schedule are absent from the result.
    /// </summary>
    Task<IReadOnlyDictionary<Guid, WorkerOverrun>> FindOverrunsAsync(
        IReadOnlyCollection<Guid> workerProfileIds,
        CancellationToken cancellationToken = default);
}
