using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.ApplyToHiringPost;

public class ApplyToHiringPostCommand : IRequest<HiringPostDto>
{
    public Guid HiringPostId { get; set; }
}
