using System.Text.Json.Serialization;
using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.RespondToHiringPostOffer;

public class RespondToHiringPostOfferCommand : IRequest<HiringPostDto>
{
    /// <summary>Bound from the route, not the body.</summary>
    [JsonIgnore]
    public Guid ApplicationId { get; set; }

    /// <summary>True takes the job and fills the slot; false declines and releases it.</summary>
    public bool Accept { get; set; }
}
