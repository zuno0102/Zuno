namespace Zuno.Domain.Enums;

/// <summary>
/// How well we actually know where a hiring post's job is.
/// </summary>
/// <remarks>
/// <para>
/// Recorded when the post is written, not worked out when it is read. A job either has a coordinate or
/// it does not, and this says how that coordinate was arrived at — so a screen can say "approximate
/// location" rather than implying a precision the data does not have.
/// </para>
/// <para>
/// Appended, never reordered: the value is stored as a number, so renumbering would silently relabel
/// every post already published.
/// </para>
/// </remarks>
public enum HiringPostLocationPrecision
{
    /// <summary>
    /// No usable location. The post cannot appear in a distance search and is listed separately
    /// instead of being hidden. Every post that predates location capture is this.
    /// </summary>
    None = 0,

    /// <summary>
    /// The centre of the district, because nothing finer could be resolved. Good enough to tell one
    /// district from another, useless for telling one part of a district from another.
    /// </summary>
    DistrictApprox = 1,

    /// <summary>The typed address was looked up and matched a real place.</summary>
    Geocoded = 2,

    /// <summary>
    /// An exact point: a place the business picked, or the address of the order the post was raised
    /// against. The only precision worth trusting at a small radius.
    /// </summary>
    Pinned = 3,
}
