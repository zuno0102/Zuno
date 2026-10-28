using Zuno.Domain.Enums;

namespace Zuno.Domain.Common;

public abstract class BaseEntity : IAuditableEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTimeOffset CreatedDate { get; set; }

    public Guid? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedDate { get; set; }

    public Guid? ModifiedBy { get; set; }

    public bool IsDeleted { get; set; }

    public EntityStatus Status { get; set; } = EntityStatus.Active;
}
