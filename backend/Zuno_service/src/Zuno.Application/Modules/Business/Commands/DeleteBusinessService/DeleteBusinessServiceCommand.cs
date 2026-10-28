using MediatR;

namespace Zuno.Application.Modules.Business.Commands.DeleteBusinessService;

public class DeleteBusinessServiceCommand : IRequest
{
    public Guid Id { get; set; }
}
