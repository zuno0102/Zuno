using MediatR;
using Zuno.Application.Modules.Worker.DTOs;

namespace Zuno.Application.Modules.Worker.Commands.SetWorkerPhoto;

/// <summary>
/// Points a worker's profile at a picture that has already been stored.
/// </summary>
/// <remarks>
/// The only thing that writes <c>WorkerProfile.PhotoUrl</c>, exactly as <c>SetBusinessLogoCommand</c>
/// is the only writer of a business logo. Keeping it out of the profile-update command matters: that
/// form posts back whatever it loaded, so a worker who uploaded a picture and then changed their
/// hourly rate would otherwise have the picture wiped as a side effect.
/// </remarks>
public class SetWorkerPhotoCommand : IRequest<WorkerProfileDto>
{
    /// <summary>Root-relative URL returned by the file store.</summary>
    public string Url { get; set; } = string.Empty;
}
