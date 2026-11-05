namespace Zuno.Application.Modules.Customer.DTOs;

public class BusinessDetailDto
{
    public Guid Id { get; set; }

    public string BusinessName { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? LogoUrl { get; set; }

    public string? AddressLine1 { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public string? Country { get; set; }

    /// <summary>The overall rating across every line it runs. Null until there are enough ratings.</summary>
    public decimal? RatingAverage { get; set; }

    public int ReviewCount { get; set; }

    /// <summary>The rating of its Service orders alone. Null until there are enough of them.</summary>
    public decimal? ServiceRatingAverage { get; set; }

    public int ServiceRatingCount { get; set; }

    /// <summary>The rating of its Rent orders alone. Null until there are enough of them.</summary>
    public decimal? RentRatingAverage { get; set; }

    public int RentRatingCount { get; set; }

    public List<CustomerServiceDto> Services { get; set; } = [];
}
