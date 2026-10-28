using Zuno.Domain.Common;

namespace Zuno.Domain.Entities;

public class State : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public ICollection<District> Districts { get; set; } = new List<District>();
}
