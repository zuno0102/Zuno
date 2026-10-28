using MediatR;
using Zuno.Application.Modules.WorkChat.DTOs;

namespace Zuno.Application.Modules.WorkChat.Queries.GetWorkMessages;

/// <summary>
/// One business–worker conversation, oldest first. Reading it marks the other side's messages read,
/// the same way a booking thread does.
/// </summary>
/// <param name="CounterpartId">The other side's profile id.</param>
public record GetWorkMessagesQuery(Guid CounterpartId) : IRequest<List<WorkMessageDto>>;
