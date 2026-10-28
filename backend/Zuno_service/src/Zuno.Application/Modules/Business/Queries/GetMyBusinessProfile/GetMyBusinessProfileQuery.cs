using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetMyBusinessProfile;

public class GetMyBusinessProfileQuery : IRequest<BusinessProfileDto>;
