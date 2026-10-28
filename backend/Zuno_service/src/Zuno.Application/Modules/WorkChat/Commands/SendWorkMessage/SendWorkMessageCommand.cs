using MediatR;
using Zuno.Application.Modules.WorkChat.DTOs;

namespace Zuno.Application.Modules.WorkChat.Commands.SendWorkMessage;

/// <summary>Writes a message to the other side of a business–worker conversation.</summary>
/// <remarks>
/// One command for both sides. The caller names the other side; which side the caller is comes from
/// their own account, so nobody can write as the other party.
/// </remarks>
public class SendWorkMessageCommand : IRequest<WorkMessageDto>
{
    /// <summary>The other side's profile id: the worker for a business, the business for a worker.</summary>
    public Guid CounterpartId { get; set; }

    public string Body { get; set; } = string.Empty;
}
