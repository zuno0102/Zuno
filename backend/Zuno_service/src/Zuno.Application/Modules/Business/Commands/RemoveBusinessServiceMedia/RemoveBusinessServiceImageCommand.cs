using MediatR;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;

public class RemoveBusinessServiceImageCommand : IRequest
{
    public Guid ServiceId { get; set; }

    public int SlotIndex { get; set; }
}
