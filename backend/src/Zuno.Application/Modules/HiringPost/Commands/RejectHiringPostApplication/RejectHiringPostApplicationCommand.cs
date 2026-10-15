using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.RejectHiringPostApplication;

public class RejectHiringPostApplicationCommand : IRequest<HiringPostDto>
{
    public Guid ApplicationId { get; set; }
}
