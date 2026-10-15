using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.ConfirmHiringPostApplication;

public class ConfirmHiringPostApplicationCommand : IRequest<HiringPostDto>
{
    public Guid ApplicationId { get; set; }
}
