using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.StartHiringPostWork;

/// <summary>
/// The business says the crew has started on the day.
/// </summary>
public class StartHiringPostWorkCommand : IRequest<HiringPostDto>
{
    public Guid HiringPostId { get; set; }
}
