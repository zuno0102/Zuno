using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceMedia;

/// <summary>
/// Puts a picture in one of a service's three slots.
/// </summary>
/// <remarks>
/// Carries the picture itself rather than a URL it has already been saved to. The controller used
/// to write the file first and send the URL here, which meant the file landed on disk before
/// anyone had checked the service belonged to the caller — and the storage layer clears the slot
/// before writing, so an upload aimed at another business's service id deleted that business's
/// picture and replaced it. The ownership check is in this handler, so the saving belongs here too.
/// </remarks>
public class SetBusinessServiceImageCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    public int SlotIndex { get; set; }

    /// <summary>The picture, read only once the caller is known to own the service.</summary>
    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Carries the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}
