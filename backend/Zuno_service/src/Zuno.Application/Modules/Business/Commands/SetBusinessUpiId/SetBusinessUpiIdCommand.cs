using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessUpiId;

/// <summary>
/// Sets only the business's UPI ID — for the "Add UPI ID" prompt next to a payment QR, which has
/// nothing else of the profile to send. The same field the full profile form saves.
/// </summary>
public class SetBusinessUpiIdCommand : IRequest<BusinessProfileDto>
{
    public string UpiId { get; set; } = string.Empty;
}
