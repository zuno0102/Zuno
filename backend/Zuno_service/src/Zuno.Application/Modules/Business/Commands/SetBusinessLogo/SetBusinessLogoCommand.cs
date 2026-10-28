using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessLogo;

/// <summary>
/// Points the signed-in business at its newly uploaded profile picture, or clears it.
/// </summary>
/// <remarks>
/// The only writer of <c>LogoUrl</c>. A profile edit deliberately leaves the field alone: the
/// edit form posts whatever copy it loaded, which can be older than a picture uploaded since,
/// and a blind overwrite there would erase the logo as a side effect of renaming the business.
/// </remarks>
public class SetBusinessLogoCommand : IRequest<BusinessProfileDto>
{
    /// <summary>The stored file's root-relative URL, or null to remove the picture.</summary>
    /// <remarks>
    /// Set by the controller from what the storage service returned, never taken from the
    /// request body — a client-supplied URL here would let one business point at another's file.
    /// </remarks>
    public string? Url { get; set; }
}
