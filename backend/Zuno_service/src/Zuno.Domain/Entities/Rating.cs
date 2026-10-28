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

    public short Score { get; set; }

    public string? Comment { get; set; }
}
