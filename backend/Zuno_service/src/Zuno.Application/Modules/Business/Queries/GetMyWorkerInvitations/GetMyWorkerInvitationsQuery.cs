using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetMyWorkerInvitations;

public class GetMyWorkerInvitationsQuery : IRequest<List<WorkerInvitationDto>>;
