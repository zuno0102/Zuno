using MediatR;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessServiceVariantVideo;

public class RemoveBusinessServiceVariantVideoCommand : IRequest
{
    public Guid ServiceId { get; set; }

    public Guid VariantId { get; set; }
}
