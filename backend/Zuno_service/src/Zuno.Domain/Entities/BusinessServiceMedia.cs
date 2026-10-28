using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

public class BusinessServiceMedia : BaseEntity
{
    /// <summary>
    /// Exactly one of <see cref="BusinessServiceId"/> or <see cref="BusinessServiceVariantId"/>
    /// is set — this table backs media for both a service and its variants.
    /// </summary>
    public Guid? BusinessServiceId { get; set; }

    public BusinessService? BusinessService { get; set; }

    public Guid? BusinessServiceVariantId { get; set; }

    public BusinessServiceVariant? BusinessServiceVariant { get; set; }

    public ServiceMediaType MediaType { get; set; }

    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}
