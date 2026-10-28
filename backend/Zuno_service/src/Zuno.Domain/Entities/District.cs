using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class District : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public State State { get; set; } = null!;

    /// <summary>
    /// Where the district headquarters is, or null for a district outside the curated states.
    /// </summary>
    /// <remarks>
    /// A rough point for a whole district, used only to place a job that has no precise location of
    /// its own. Never used to compare two jobs whose real positions are known: everything inside one
    /// district is zero apart by this measure.
    /// </remarks>
    public decimal? CentreLatitude { get; set; }

    public decimal? CentreLongitude { get; set; }
}
