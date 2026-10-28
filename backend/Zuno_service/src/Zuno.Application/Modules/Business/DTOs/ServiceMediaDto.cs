namespace Zuno.Application.Modules.Business.DTOs;

public class ServiceMediaDto
{
    public Guid Id { get; set; }

    public string MediaType { get; set; } = string.Empty;

    public string Url { get; set; } = string.Empty;

    public short SortOrder { get; set; }
}
