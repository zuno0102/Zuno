namespace Zuno.Domain.Common;

public interface IAuditableEntity
{
    Guid Id { get; }
    DateTimeOffset CreatedDate { get; set; }
    Guid? CreatedBy { get; set; }
    DateTimeOffset? ModifiedDate { get; set; }
    Guid? ModifiedBy { get; set; }
    bool IsDeleted { get; set; }
}
