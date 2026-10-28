using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceVariantImage;

/// <summary>
/// Puts a picture in one of a package's slots. Carries the file for the reason given on
/// <c>SetBusinessServiceImageCommand</c>: nothing is written until the caller is known to own the
/// service the package belongs to.
/// </summary>
public class SetBusinessServiceVariantImageCommand : IRequest<BusinessServiceDto>
{
    public Guid ServiceId { get; set; }

    public Guid VariantId { get; set; }

    public int SlotIndex { get; set; }

    public Stream Content { get; set; } = Stream.Null;

    /// <summary>Carries the dot, e.g. <c>.jpg</c>.</summary>
    public string FileExtension { get; set; } = ".jpg";
}
