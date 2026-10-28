namespace Zuno.Domain.ValueObjects;

/// <summary>
/// What a crew member is on one particular job: Supervisor, Lead or Support.
/// </summary>
/// <remarks>
/// <para>
/// A fixed set of three, not free text. "Painter", "Chef" and "Driver" describe the trade somebody
/// practises, which is a fact about the person and the same on every job they take. These three
/// describe what they are doing <b>on this order</b>, which is a different question and the only
/// one worth recording per job.
/// </para>
/// <para>
/// They apply to every category. A lead on a painting job and a lead on a catering job lead in the
/// same sense — the work differs, the job of leading it does not — so the choice is never narrowed
/// by what the order is for.
/// </para>
/// <para>
/// <b>Only <see cref="Lead"/> carries any power</b>, and only one: marking this job's work started
/// and finished. Supervisor and Support are recorded titles. That is deliberate — a job has one
/// person answerable for whether the work has begun, and three roles that could all declare it
/// would mean nobody in particular did.
/// </para>
/// <para>
/// Everything here ends with the order. The role is held against one assignment, so when the job is
/// over the person is a plain worker again, with nothing to remove and nothing left behind on the
/// next job.
/// </para>
/// </remarks>
public static class JobRole
{
    /// <summary>Watches how the work is going. Sees the job; changes nothing.</summary>
    public const string Supervisor = "Supervisor";

    /// <summary>
    /// Runs the work on the day, and the only role that can move its status.
    /// </summary>
    /// <remarks>
    /// The one real power in this set, and the reason it is a set rather than a flag: somebody has
    /// to be able to say the work began without the owner being on site, and it has to be one
    /// somebody.
    /// </remarks>
    public const string Lead = "Lead";

    /// <summary>
    /// Fixes whatever the job needs around the work — food for the crew, a missing supply, a
    /// problem nobody else has time for.
    /// </summary>
    public const string Support = "Support";

    /// <summary>The three, in the order they are offered.</summary>
    public static readonly IReadOnlyList<string> All = [Supervisor, Lead, Support];

    /// <summary>Whether this is one of the three.</summary>
    /// <remarks>
    /// Case-insensitive, so a role typed by an older build or a different client still matches.
    /// </remarks>
    public static bool IsKnown(string? role) =>
        role is not null && All.Any(r => string.Equals(r, role.Trim(), StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// The stored spelling — "lead" and "LEAD" both become "Lead".
    /// </summary>
    /// <remarks>
    /// Normalised on the way in rather than compared loosely everywhere afterwards. The value is
    /// shown to people on the crew list and on the worker's own screen, and "LEAD" shouting out of
    /// one row is the kind of thing that only ever gets noticed in a screenshot.
    /// </remarks>
    public static string? Canonical(string? role)
    {
        if (string.IsNullOrWhiteSpace(role)) return null;

        return All.FirstOrDefault(r => string.Equals(r, role.Trim(), StringComparison.OrdinalIgnoreCase))
            // Left as typed when it is not one of the three. The validator refuses those, so this
            // only ever sees a legacy value being read back.
            ?? role.Trim();
    }

    /// <summary>
    /// Whether holding this role lets somebody start and finish the job's work.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Only Lead. Asked here rather than compared inline anywhere, because this single line is the
    /// whole of what a role grants in this app — and a second copy of it is how the answer starts
    /// differing between the screen that offers a button and the handler that refuses it.
    /// </para>
    /// <para>
    /// Legacy rows matter here. Free-text roles — "Painter", "Chef" — were written before this set
    /// existed and are still on old assignments. They are not Lead, so they grant nothing, which is
    /// the right answer: nobody ever chose them meaning "can close this job".
    /// </para>
    /// </remarks>
    public static bool GrantsWorkControl(string? role) =>
        role is not null && string.Equals(Lead, role.Trim(), StringComparison.OrdinalIgnoreCase);
}
