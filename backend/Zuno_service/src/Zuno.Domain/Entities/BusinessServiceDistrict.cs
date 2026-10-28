using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class BusinessServiceDistrict : BaseEntity
{
    public Guid BusinessServiceId { get; set; }

    public BusinessService BusinessService { get; set; } = null!;

    public Guid DistrictId { get; set; }

    public District District { get; set; } = null!;
}
