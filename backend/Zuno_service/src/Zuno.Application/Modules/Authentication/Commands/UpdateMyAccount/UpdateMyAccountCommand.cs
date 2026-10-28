using MediatR;
using Zuno.Application.Modules.Authentication.DTOs;

namespace Zuno.Application.Modules.Authentication.Commands.UpdateMyAccount;

/// <summary>
/// Lets somebody correct their own name and phone number.
/// </summary>
/// <remarks>
/// On the account rather than a per-role profile, because these three fields live on the user and
/// every role has them. A customer, a worker and a business owner all mistype a phone number the same
/// way, and three copies of this would be three places for the uniqueness rule to drift.
///
/// Email is deliberately absent. It is the account's identity and half of how somebody signs in, so
/// changing it needs proof the new address is theirs — a verification round trip this does not have.
/// </remarks>
public class UpdateMyAccountCommand : IRequest<UserDto>
{
    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    /// <summary>Null clears it. A customer who has an email does not have to keep a number on file.</summary>
    public string? PhoneNumber { get; set; }
}
