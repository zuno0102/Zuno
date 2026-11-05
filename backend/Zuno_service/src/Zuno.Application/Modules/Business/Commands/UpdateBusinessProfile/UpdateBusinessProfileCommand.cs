using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.UpdateBusinessProfile;

public class UpdateBusinessProfileCommand : IRequest<BusinessProfileDto>
{
    public string BusinessName { get; set; } = string.Empty;

    public string? BusinessType { get; set; }

    public string? GstNumber { get; set; }

    public string? Description { get; set; }

    /// <summary>
    /// Where customers pay by UPI, e.g. joyevents@okhdfcbank. Required: every payment QR the business
    /// shows is made from it. Left out (null) by an app from before the profile held it: the saved
    /// one is kept, so that app can still save the rest of the profile.
    /// </summary>
    public string? UpiId { get; set; }

    /// <summary>Accepted and ignored. The profile picture is set by uploading one.</summary>
    /// <remarks>
    /// Still bound so existing clients that echo the whole profile back keep working, but the
    /// handler does not read it — see SetBusinessLogoCommand for why there is exactly one writer.
    /// </remarks>
    public string? LogoUrl { get; set; }

    public string? AddressLine1 { get; set; }

    public string? AddressLine2 { get; set; }

    public string? City { get; set; }

    public string? State { get; set; }

    public string? PostalCode { get; set; }

    public string? Country { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }
}
