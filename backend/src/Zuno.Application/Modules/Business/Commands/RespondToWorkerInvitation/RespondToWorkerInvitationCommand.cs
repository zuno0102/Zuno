using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.RespondToWorkerInvitation;

public class RespondToWorkerInvitationCommand : IRequest<WorkerInvitationDto>
{
    public Guid Id { get; set; }

    public bool Accept { get; set; }
}
