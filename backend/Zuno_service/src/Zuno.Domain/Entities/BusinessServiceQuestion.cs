using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

/// <summary>
/// Something a business needs to know from the customer before it can staff a job.
/// </summary>
/// <remarks>
/// A caterer asks for the dish count and the number of servings; a painter asks for wall sizes.
/// The business writes its own, because no fixed set of fields fits both — and the answers are
/// what tell it how many people the job actually needs.
///
/// Attached to the service rather than the variant: every booking has a service, while the
/// variant is optional, so questions on a variant would leave some orders unasked.
/// </remarks>
public class BusinessServiceQuestion : BaseEntity
{
    public Guid BusinessServiceId { get; set; }

    public BusinessService BusinessService { get; set; } = null!;

    /// <summary>What the customer is asked, in the business's own words.</summary>
    public string Prompt { get; set; } = string.Empty;

    /// <summary>Whether the customer must answer before the order can be placed.</summary>
    public bool IsRequired { get; set; }

    public short SortOrder { get; set; }
}
