using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class CustomerProfile : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public Guid? DefaultAddressId { get; set; }

    public Address? DefaultAddress { get; set; }

    public string PreferredLanguage { get; set; } = "en";

    /// <summary>
    /// Where the customer is: the district their listings are narrowed to, in Service, Rent and
    /// whatever comes next. Read from the phone when the app opens, or picked by hand. Null for
    /// everywhere.
    /// </summary>
    public Guid? LocationDistrictId { get; set; }

    public District? LocationDistrict { get; set; }

    /// <summary>How the location was last set — see <see cref="CustomerLocationSources"/>; null if never.</summary>
    public string? LocationSource { get; set; }

    public DateTimeOffset? LocationUpdatedAt { get; set; }

    public ICollection<Booking> Bookings { get; set; } = new List<Booking>();
}

/// <summary>How a customer's location was set, which decides whether the app may change it by itself.</summary>
public static class CustomerLocationSources
{
    /// <summary>Read from the phone. The app updates it on the next open if they have moved.</summary>
    public const string Gps = "Gps";

    /// <summary>Picked by hand. The app leaves it alone.</summary>
    public const string Manual = "Manual";

    /// <summary>Cleared to everywhere on purpose. The app leaves that alone too.</summary>
    public const string Cleared = "Cleared";

    public const int MaxLength = 10;

    public static readonly IReadOnlyList<string> All = [Gps, Manual, Cleared];
}
