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

    public List<CustomerServiceDto> Services { get; set; } = [];
}
