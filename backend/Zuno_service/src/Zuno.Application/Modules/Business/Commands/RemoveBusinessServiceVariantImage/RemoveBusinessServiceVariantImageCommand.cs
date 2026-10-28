using MediatR;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantImage;

public class RemoveBusinessServiceVariantImageCommand : IRequest
{
    public Guid ServiceId { get; set; }

    public Guid VariantId { get; set; }

    public int SlotIndex { get; set; }
}
