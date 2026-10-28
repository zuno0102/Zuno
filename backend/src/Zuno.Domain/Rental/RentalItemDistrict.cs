using Zuno.Domain.Common;

namespace Zuno.Domain.Rental;

/// <summary>
/// One district in a <see cref="RentalItem"/>'s service area.
/// </summary>
/// <remarks>
/// Holds the district's id only, with no navigation into the core model: the Rent module reads the
/// district list but never owns or changes it. The foreign key to the core table is enforced in the
/// database.
/// </remarks>
public class RentalItemDistrict : BaseEntity
{
    public Guid RentalItemId { get; set; }

    public RentalItem RentalItem { get; set; } = null!;

    public Guid DistrictId { get; set; }
}
