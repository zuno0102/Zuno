using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.InviteWorkerToHiringPost;

public class InviteWorkerToHiringPostCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid HiringPostId { get; set; }

    /// <summary>The email or phone number the worker registered with.</summary>
    public string WorkerIdentifier { get; set; } = string.Empty;
}
