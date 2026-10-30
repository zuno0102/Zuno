using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// How a rate type is shown and whether it is offered — "Per day", the line under it, and the
/// "/day" after a price. Table-driven: rows, not code, so a name or the order changes without a release.
/// </summary>
public class RentalPriceTypeOption
{
    /// <summary>The rate type this row describes; also the key.</summary>
    public RentalPriceType Code { get; set; }

    public string Name { get; set; } = string.Empty;

    /// <summary>The line under the name on the form's card.</summary>
    public string Detail { get; set; } = string.Empty;

    /// <summary>Written after a price on the item card, e.g. "/day".</summary>
    public string UnitSuffix { get; set; } = string.Empty;

    public short DisplayOrder { get; set; }

    /// <summary>Off takes the option off the form and refuses it for new saves.</summary>
    public bool IsActive { get; set; } = true;
}
