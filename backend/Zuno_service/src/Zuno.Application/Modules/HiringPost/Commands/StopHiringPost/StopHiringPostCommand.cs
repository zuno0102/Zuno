using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.StopHiringPost;

public class StopHiringPostCommand : IRequest<HiringPostDto>
{
    public Guid HiringPostId { get; set; }
}
