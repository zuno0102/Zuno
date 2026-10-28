using MediatR;

namespace Zuno.Application.Modules.HiringPost.Commands.DeleteHiringPost;

public class DeleteHiringPostCommand : IRequest
{
    public Guid HiringPostId { get; set; }
}
