using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Commands.SetMyAccountPhoto;

/// <summary>Records the picture the signed-in account has just uploaded.</summary>
/// <remarks>
/// Separate from the account save, which carries name and phone: an upload changes one field, and
/// routing it through the full save would let a half-filled form blank somebody's name as a side
/// effect of changing their picture.
/// </remarks>
public class SetMyAccountPhotoCommand : IRequest<UserDto>
{
    /// <summary>The root-relative URL the storage service returned.</summary>
    public string Url { get; set; } = string.Empty;
}
