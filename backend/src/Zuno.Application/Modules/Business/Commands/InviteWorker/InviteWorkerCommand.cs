using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.InviteWorker;

public class InviteWorkerCommand : IRequest<BusinessWorkerDto>
{
    /// <summary>Email address or phone number identifying the worker's registered account.</summary>
    public string WorkerIdentifier { get; set; } = string.Empty;
}
