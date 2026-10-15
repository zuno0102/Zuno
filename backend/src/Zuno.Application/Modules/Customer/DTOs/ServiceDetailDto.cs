namespace Zuno.Application.Modules.Customer.DTOs;

/// <summary>
/// One service opened on its own: everything it is sold as, plus enough about the business
/// behind it that a customer can decide without leaving the page.
/// </summary>
public class ServiceDetailDto
{
    public CustomerServiceDto Service { get; set; } = new();

    public BusinessSummaryDto Business { get; set; } = new();
}
