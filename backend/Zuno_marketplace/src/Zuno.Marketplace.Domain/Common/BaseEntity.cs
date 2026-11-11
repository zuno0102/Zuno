namespace Zuno.Marketplace.Domain.Common;

public interface IAuditableEntity
{
    public DateTimeOffset CreatedDate { get; set; }

    public Guid? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedDate { get; set; }

    public Guid? ModifiedBy { get; set; }

    public bool IsDeleted { get; set; }
}

/// <summary>Every Marketplace row: an id, who made and last changed it, and a soft-delete flag.</summary>
public abstract class BaseEntity : IAuditableEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTimeOffset CreatedDate { get; set; }

    public Guid? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedDate { get; set; }

    public Guid? ModifiedBy { get; set; }

    public bool IsDeleted { get; set; }
}
