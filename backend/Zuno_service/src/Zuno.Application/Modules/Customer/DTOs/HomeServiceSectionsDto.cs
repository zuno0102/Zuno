namespace Zuno.Application.Modules.Customer.DTOs;

/// <summary>
/// Everything the customer's home screen lists, in one answer.
/// </summary>
/// <remarks>
/// One request rather than four, because the sections have to be composed together: no service
/// appears in two of them, and no section shows the same service name twice. Fetched separately they
/// could not know about each other, which is exactly how the page came to show "Catering by Boss T"
/// six times in a row — the catalogue holds many near-identical rows, and every section picked the
/// same ones for the same good reasons.
/// </remarks>
public class HomeServiceSectionsDto
{
    /// <summary>The opening grid: a spread of what is available, shuffled daily.</summary>
    public List<ServiceListingDto> ForYou { get; set; } = [];

    /// <summary>What customers actually book most, counted from orders.</summary>
    public List<ServiceListingDto> MostBooked { get; set; } = [];

    /// <summary>More of the catalogue, none of it already shown above.</summary>
    public List<ServiceListingDto> More { get; set; } = [];

    /// <summary>Best rated by customers, among businesses with enough reviews to mean it.</summary>
    public List<ServiceListingDto> TopRated { get; set; } = [];

    /// <summary>The long list at the bottom.</summary>
    public List<ServiceListingDto> All { get; set; } = [];
}
