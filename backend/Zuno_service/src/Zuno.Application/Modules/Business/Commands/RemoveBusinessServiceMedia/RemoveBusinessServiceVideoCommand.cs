using MediatR;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceMedia;

public class RemoveBusinessServiceVideoCommand : IRequest
{
    public Guid ServiceId { get; set; }
}
