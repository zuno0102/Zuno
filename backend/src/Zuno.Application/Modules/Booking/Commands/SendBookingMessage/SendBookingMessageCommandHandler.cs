using MediatR;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.SendBookingMessage;

public class SendBookingMessageCommandHandler(
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext,
    IPublisher publisher)
    : IRequestHandler<SendBookingMessageCommand, BookingMessageDto>
{
    public async Task<BookingMessageDto> Handle(
        SendBookingMessageCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Refuses anybody who is not one of the two parties, and tells us which one is writing.
        var sender = await BookingThreadAccess.ResolveAsync(
            dbContext,
            request.BookingId,
            userId,
            cancellationToken);

        // The window: confirmed and onwards, and never once called off. Enforced here rather than
        // only hidden in the app, because the app is not what keeps a cancelled order from being
        // written on.
        if (!BookingThreadAccess.CanMessage(sender.BookingStatus, sender.HasRating))
        {
            throw new DomainException(
                sender.BookingStatus switch
                {
                    Domain.Enums.BookingStatus.Cancelled =>
                        "This order was cancelled, so its conversation is closed.",
                    Domain.Enums.BookingStatus.Completed =>
                        "You rated this order, which closed its conversation.",
                    _ => "You can message once the business has confirmed this order.",
                });
        }

        var message = new BookingMessage
        {
            BookingId = request.BookingId,
            SenderRole = sender.Role,
            SenderUserId = sender.UserId,
            Body = request.Body.Trim(),
            CreatedDate = dateTimeProvider.UtcNow,
        };

        dbContext.BookingMessages.Add(message);
        await dbContext.SaveChangesAsync(cancellationToken);

        // The whole reason this feature exists in a chat app: the other side is not looking at the
        // screen. The app's own 6-second poll only helps somebody who already has the thread open.
        await publisher.Publish(
            new BookingMessageSentEvent(
                message.BookingId,
                sender.CounterpartUserId,
                sender.DisplayName,
                message.Body),
            cancellationToken);

        return new BookingMessageDto
        {
            Id = message.Id,
            BookingId = message.BookingId,
            SenderRole = message.SenderRole.ToString(),
            // Always true: you are reading back what you just sent.
            IsMine = true,
            SenderName = sender.DisplayName,
            Body = message.Body,
            SentAt = message.CreatedDate,
            ReadAt = null,
        };
    }
}
