using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantVideo;

/// <summary>
/// Sets the video on a package. Carries the file for the reason given on
/// <c>SetBusinessServiceImageCommand</c>: nothing is written until the caller is known to own the
/// service the package belongs to.
/// </summary>
public class SetBusinessServiceVariantVideoCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    public Guid VariantId { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Carries the dot, e.g. <c>.mp4</c>.</summary>
    public string FileExtension { get; set; } = ".mp4";
}
