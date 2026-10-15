using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class Address : BaseEntity
{
    public Guid OwnerUserId { get; set; }

    public User OwnerUser { get; set; } = null!;

    public string? Label { get; set; }

    public string Line1 { get; set; } = string.Empty;

    public string? Line2 { get; set; }

    public string City { get; set; } = string.Empty;

    public string State { get; set; } = string.Empty;

    public string PostalCode { get; set; } = string.Empty;

    public string Country { get; set; } = "India";

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public bool IsDefault { get; set; }
}
