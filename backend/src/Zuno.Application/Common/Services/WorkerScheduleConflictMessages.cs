using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Common.Services;

/// <summary>
/// Phrases a scheduling clash for the person reading it. Kept in one place so the business and
/// the worker are told the same story about the same clash, differing only in who it names.
/// </summary>
public static class WorkerScheduleConflictMessages
{
    /// <summary>Addressed to the business, naming the worker.</summary>
    public static string ForBusiness(
        WorkerScheduleConflict clash,
        string workerName,
        int bufferMinutes,
        DateTimeOffset jobStartsAt)
    {
        if (clash.Kind == WorkerScheduleConflictKind.Unfinished)
        {
            return $"{workerName} is still on \"{clash.Title}\", which nobody has marked " +
                   "completed. Close that job off and they are free for this one.";
        }

        if (clash.Kind == WorkerScheduleConflictKind.Overlap)
        {
            return $"{workerName} is already working \"{clash.Title}\" from " +
                   $"{Window(clash)}, which overlaps this event.";
        }

        // "More than", not "at least": a gap of exactly the buffer is refused, and a message
        // saying 30 is enough while the server rejects 30 sends the business round in circles.
        return $"{workerName} {Neighbour(clash, jobStartsAt)} " +
               $"Only {clash.GapMinutes} minute(s) between the two, and more than " +
               $"{bufferMinutes} minutes is needed to travel between jobs.";
    }

    /// <summary>Addressed to the worker themselves.</summary>
    public static string ForWorker(
        WorkerScheduleConflict clash,
        int bufferMinutes,
        DateTimeOffset jobStartsAt)
    {
        if (clash.Kind == WorkerScheduleConflictKind.Unfinished)
        {
            return $"You are still on \"{clash.Title}\" — it has not been marked completed yet. " +
                   "Once it is, you can take this one.";
        }

        if (clash.Kind == WorkerScheduleConflictKind.Overlap)
        {
            return $"You are already working \"{clash.Title}\" from {Window(clash)}, " +
                   "which overlaps this job. Finish or give up that work before taking this one.";
        }

        return $"You {Neighbour(clash, jobStartsAt, secondPerson: true)} " +
               $"Only {clash.GapMinutes} minute(s) between the two, and you need more than " +
               $"{bufferMinutes} minutes to get from one to the other.";
    }

    /// <summary>
    /// Names the boundary that actually matters. When the existing job runs first, that is when
    /// it finishes; when it runs second, it is when it starts — quoting the wrong end of it
    /// leaves the reader unable to see where the squeeze is.
    /// </summary>
    private static string Neighbour(
        WorkerScheduleConflict clash,
        DateTimeOffset jobStartsAt,
        bool secondPerson = false)
    {
        var finish = secondPerson ? "finish" : "finishes";
        var start = secondPerson ? "start" : "starts";

        return clash.EndsAt <= jobStartsAt
            ? $"{finish} \"{clash.Title}\" at {clash.EndsAt.ToLocalTime():HH:mm}, just before this job begins."
            : $"{start} \"{clash.Title}\" at {clash.StartsAt.ToLocalTime():HH:mm}, right after this job ends.";
    }

    private static string Window(WorkerScheduleConflict clash) =>
        $"{clash.StartsAt.ToLocalTime():dd MMM HH:mm} to {clash.EndsAt.ToLocalTime():HH:mm}";
}
