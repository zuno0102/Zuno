using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessService;

public class CreateBusinessServiceCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceCategoryId { get; set; }

    /// <summary>The trade within the category. Optional.</summary>
    public Guid? ServiceSubCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? ItemName { get; set; }

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }

    public int RequiredWorkerCount { get; set; } = 1;

    public List<Guid> DistrictIds { get; set; } = [];
}
