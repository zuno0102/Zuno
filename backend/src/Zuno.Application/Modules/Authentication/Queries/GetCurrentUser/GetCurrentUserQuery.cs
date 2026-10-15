using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Queries.GetCurrentUser;

public class GetCurrentUserQuery : IRequest<UserDto>;
