namespace Zuno.Application.Modules.Business.DTOs;

public class ServiceDistrictDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid StateId { get; set; }

    public string StateName { get; set; } = string.Empty;
}
