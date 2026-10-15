using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.CreateBusinessServiceVariant;

public class CreateBusinessServiceVariantCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    /// <summary>
    /// The kind of work this item is. Must belong to the parent service's category —
    /// the main category is never chosen again here, it is inherited.
    /// </summary>
    public Guid? ServiceSubCategoryId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string PriceType { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public short? EstimatedDurationMinutes { get; set; }
}
