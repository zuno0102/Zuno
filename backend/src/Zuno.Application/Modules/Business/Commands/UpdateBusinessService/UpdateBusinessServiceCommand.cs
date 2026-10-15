using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessService;

public class UpdateBusinessServiceCommand : IRequest<BusinessServiceDto>
{
    public Guid Id { get; set; }

    public Guid ServiceCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? ItemName { get; set; }

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public int RequiredWorkerCount { get; set; } = 1;

    public bool IsActive { get; set; }

    public List<Guid> DistrictIds { get; set; } = [];
}
