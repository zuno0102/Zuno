using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;

/// <summary>
/// Sets the video on a service. Carries the file for the reason given on
/// <see cref="SetBusinessServiceImageCommand"/>: nothing is written until the caller is known to
/// own the service.
/// </summary>
public class SetBusinessServiceVideoCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Carries the dot, e.g. <c>.mp4</c>.</summary>
    public string FileExtension { get; set; } = ".mp4";
}
