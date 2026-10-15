using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetBusinessDashboard;

/// <summary>The signed-in business's home screen.</summary>
public class GetBusinessDashboardQuery : IRequest<BusinessDashboardDto>;
