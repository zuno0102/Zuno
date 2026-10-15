namespace Zuno.Application.Modules.Business.DTOs;

public class BusinessProfileDto
{
    public Guid Id { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessType { get; set; }

    public string? GstNumber { get; set; }

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string VerificationStatus { get; set; } = string.Empty;

    public string? AddressLine1 { get; set; }

    public string? AddressLine2 { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public string? PostalCode { get; set; }

    public string? Country { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    /// <summary>The two-sided record: what customers see, and what workers see.</summary>
    public BusinessTrustDto Trust { get; set; } = new();

    /// <summary>1-5, earned from jobs seen through and paid for.</summary>
    public int Level { get; set; } = 1;

    public string LevelName { get; set; } = string.Empty;
}
