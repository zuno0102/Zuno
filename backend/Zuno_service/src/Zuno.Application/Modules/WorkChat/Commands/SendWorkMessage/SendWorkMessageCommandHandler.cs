using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.WorkChat.Common;
using Zuno.Application.Modules.WorkChat.DTOs;
using Zuno.Application.Modules.WorkChat.Events;
using Zuno.Domain.Entities;

namespace Zuno.Application.Modules.WorkChat.Commands.SendWorkMessage;

public class SendWorkMessageCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext,
    IPublisher publisher)
    : IRequestHandler<SendWorkMessageCommand, WorkMessageDto>
{
    public async Task<WorkMessageDto> Handle(
        SendWorkMessageCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Refuses anybody who is not the business or a worker on its team.
        var sender = await WorkThreadAccess.ResolveAsync(
            dbContext,
            userId,
            request.CounterpartId,
            cancellationToken);

        var message = new WorkMessage
        {
            BusinessOwnerProfileId = sender.BusinessOwnerProfileId,
            WorkerProfileId = sender.WorkerProfileId,
            SenderRole = sender.Role,
            SenderUserId = sender.UserId,
            Body = request.Body.Trim(),
            CreatedDate = dateTimeProvider.UtcNow,
        };

        dbContext.WorkMessages.Add(message);
        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new WorkMessageSentEvent(
                sender.CounterpartUserId,
                sender.OwnProfileId,
                sender.DisplayName,
                message.Body),
            cancellationToken);

        return new WorkMessageDto
        {
            Id = message.Id,
            CounterpartId = request.CounterpartId,
            SenderRole = message.SenderRole.ToString(),
            IsMine = true,
            SenderName = sender.DisplayName,
            Body = message.Body,
            SentAt = message.CreatedDate,
            ReadAt = null,
        };
    }
}
