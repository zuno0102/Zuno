using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class AdminProfile : BaseEntity
{
    public Guid UserId { get; set; }

    public User User { get; set; } = null!;

    public short AdminLevel { get; set; } = 1;
}
