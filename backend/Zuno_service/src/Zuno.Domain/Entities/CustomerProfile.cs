using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class CustomerProfile : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public Guid? DefaultAddressId { get; set; }

    public Address? DefaultAddress { get; set; }

    public string PreferredLanguage { get; set; } = "en";

    public ICollection<Booking> Bookings { get; set; } = new List<Booking>();
}
