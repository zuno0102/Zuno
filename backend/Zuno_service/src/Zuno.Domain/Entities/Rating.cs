using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class Rating : BaseEntity
{
    public Guid BookingId { get; set; }

    public Booking Booking { get; set; } = null!;

    public Guid CustomerProfileId { get; set; }

    public CustomerProfile CustomerProfile { get; set; } = null!;

    public Guid BusinessOwnerProfileId { get; set; }

    public BusinessOwnerProfile BusinessOwnerProfile { get; set; } = null!;

    /// <summary>
    /// The service the rated order was for, so each service shows its own stars. Null only for a rating
    /// whose order no longer names a service.
    /// </summary>
    public Guid? BusinessServiceId { get; set; }

    public BusinessService? BusinessService { get; set; }

    public short Score { get; set; }

    public string? Comment { get; set; }
}
