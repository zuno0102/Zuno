using MediatR;

namespace Zuno.Application.Modules.Business.Commands.DeleteBusinessServiceVariant;

public class DeleteBusinessServiceVariantCommand : IRequest
{
    public Guid ServiceId { get; set; }

    public Guid VariantId { get; set; }
}
