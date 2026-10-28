using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.CompleteHiringPostWork;

public class CompleteHiringPostWorkCommand : IRequest<HiringPostDto>
{
    public Guid HiringPostId { get; set; }
}
