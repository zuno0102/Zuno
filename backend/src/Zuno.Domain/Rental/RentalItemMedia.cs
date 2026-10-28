using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Rental;

/// <summary>One photo (in a numbered slot) or the video of a <see cref="RentalItem"/>.</summary>
public class RentalItemMedia : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    public ServiceMediaType MediaType { get; set; }

    public string Url { get; set; } = string.Empty;

    /// <summary>The image slot (0, 1, 2…); 0 for the video.</summary>
    public short SortOrder { get; set; }
}
