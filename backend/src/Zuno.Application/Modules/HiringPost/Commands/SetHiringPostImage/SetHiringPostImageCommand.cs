using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Commands.SetHiringPostImage;

/// <summary>
/// Sets the picture on a hiring post. Carries the file rather than a URL already written to disk,
/// so that nothing is written until the caller is known to own the post — see
/// <c>SetBusinessServiceImageCommand</c> for what the old order allowed.
/// </summary>
public class SetHiringPostImageCommand : IRequest<HiringPostDto>
{
    public Guid HiringPostId { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Carries the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}
