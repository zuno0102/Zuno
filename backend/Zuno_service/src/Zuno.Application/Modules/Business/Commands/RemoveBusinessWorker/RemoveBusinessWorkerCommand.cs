using MediatR;

namespace Zuno.Application.Modules.Business.Commands.RemoveBusinessWorker;

public class RemoveBusinessWorkerCommand : IRequest
{
    public Guid Id { get; set; }
}
