using MediatR;
using Zuno.Application.Modules.Worker.DTOs;

namespace Zuno.Application.Modules.Worker.Queries.GetWorkerDashboard;

/// <summary>
/// The worker's home screen. Takes nothing: the worker is whoever is signed in.
/// </summary>
public class GetWorkerDashboardQuery : IRequest<WorkerDashboardDto>;
