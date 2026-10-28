using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyHiringPosts;

public class GetMyHiringPostsQuery : IRequest<List<HiringPostDto>>;
