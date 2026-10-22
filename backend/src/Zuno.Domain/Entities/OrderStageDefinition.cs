using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// How one <see cref="OrderStage"/> is presented: its name, colour, position and where it appears.
/// </summary>
/// <remarks>
/// Data, not code (CODING_STANDARDS §1): renaming "Awaiting payment", reordering the filters or
/// taking a stage off a tab is a change to this row, picked up by every app without a release.
/// </remarks>
public class OrderStageDefinition : BaseEntity
{
    public OrderStage Stage { get; set; }

    /// <summary>What the chip and filter say: "Awaiting payment".</summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>Position in the filter row, lowest first.</summary>
    public int SortOrder { get; set; }

    /// <summary>
    /// The chip's colour family — <c>success</c>, <c>progress</c>, <c>waiting</c> or <c>danger</c>.
    /// A key the apps map to their theme, so the theme still owns the actual colours.
    /// </summary>
    public string Tone { get; set; } = string.Empty;

    /// <summary>A filter on the business's Bookings tab.</summary>
    public bool ShowOnBookings { get; set; }

    /// <summary>A filter on the business's Status management tab.</summary>
    public bool ShowOnWork { get; set; }
}
