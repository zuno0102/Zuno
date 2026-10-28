using MediatR;
using Zuno.Application.Modules.Worker.DTOs;

namespace Zuno.Application.Modules.Worker.Queries.GetMyWorkerProfile;

/// <summary>The signed-in worker's own profile and earnings record.</summary>
public class GetMyWorkerProfileQuery : IRequest<WorkerProfileDto>;
