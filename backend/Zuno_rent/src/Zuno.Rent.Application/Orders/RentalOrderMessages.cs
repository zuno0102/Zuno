using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;

namespace Zuno.Rent.Application.Orders;

/// <summary>A rent order's conversation, oldest first. Opening it marks the customer's messages read.</summary>
public class GetRentalOrderMessagesQuery : IRequest<List<RentalOrderMessageDto>>
{
    public Guid RentalOrderId { get; set; }
}

/// <summary>The business writes to the customer about a rent order.</summary>
public class SendRentalOrderMessageCommand : IRequest<RentalOrderMessageDto>
{
    /// <summary>From the route.</summary>
    public Guid RentalOrderId { get; set; }

    public string Body { get; set; } = string.Empty;
}

/// <summary>The business's rent conversations, latest first — the Rent Messages list.</summary>
public class GetRentalOrderThreadsQuery : IRequest<List<RentalOrderThreadDto>>;

public class RentalOrderMessageDto
{
    public Guid Id { get; set; }

    public Guid RentalOrderId { get; set; }

    /// <summary><c>Business</c> or <c>Customer</c>.</summary>
    public string SenderRole { get; set; } = string.Empty;

    /// <summary>Whether the business reading wrote it — decided here, not in the app.</summary>
    public bool IsMine { get; set; }

    public string SenderName { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public DateTimeOffset SentAt { get; set; }

    public DateTimeOffset? ReadAt { get; set; }
}

public class RentalOrderThreadDto
{
    public Guid RentalOrderId { get; set; }

    public string CustomerName { get; set; } = string.Empty;

    /// <summary>The business, for the customer's list.</summary>
    public string? BusinessName { get; set; }

    public string ItemName { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public string LastMessage { get; set; } = string.Empty;

    public DateTimeOffset LastMessageAt { get; set; }

    /// <summary>Whether the last word was the customer's.</summary>
    public bool LastFromCustomer { get; set; }

    public int UnreadCount { get; set; }
}

public class SendRentalOrderMessageCommandValidator : AbstractValidator<SendRentalOrderMessageCommand>
{
    public const int BodyMaxLength = 1000;

    public SendRentalOrderMessageCommandValidator()
    {
        RuleFor(x => x.RentalOrderId).NotEmpty();
        RuleFor(x => x.Body)
            .Must(body => !string.IsNullOrWhiteSpace(body))
            .WithMessage("Type a message.")
            .MaximumLength(BodyMaxLength);
    }
}

/// <summary>The customer's side of a rent order's conversation, oldest first; opening it marks the business's messages read.</summary>
public class GetMyRentalOrderMessagesQuery : IRequest<List<RentalOrderMessageDto>>
{
    public Guid RentalOrderId { get; set; }
}

/// <summary>The customer writes to the business about a rent order.</summary>
public class SendMyRentalOrderMessageCommand : IRequest<RentalOrderMessageDto>
{
    /// <summary>From the route.</summary>
    public Guid RentalOrderId { get; set; }

    public string Body { get; set; } = string.Empty;
}

/// <summary>The customer's rent conversations, latest first — My rents › Messages.</summary>
public class GetMyRentalOrderThreadsQuery : IRequest<List<RentalOrderThreadDto>>;

public class SendMyRentalOrderMessageCommandValidator : AbstractValidator<SendMyRentalOrderMessageCommand>
{
    public SendMyRentalOrderMessageCommandValidator()
    {
        RuleFor(x => x.RentalOrderId).NotEmpty();
        RuleFor(x => x.Body)
            .Must(body => !string.IsNullOrWhiteSpace(body))
            .WithMessage("Type a message.")
            .MaximumLength(SendRentalOrderMessageCommandValidator.BodyMaxLength);
    }
}

/// <summary>Both sides' message requests, served by one conversation — the side comes from the route.</summary>
public class RentalOrderMessageHandlers(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    TimeProvider clock,
    IOptions<RentSettings> settings) :
    IRequestHandler<GetRentalOrderMessagesQuery, List<RentalOrderMessageDto>>,
    IRequestHandler<SendRentalOrderMessageCommand, RentalOrderMessageDto>,
    IRequestHandler<GetRentalOrderThreadsQuery, List<RentalOrderThreadDto>>,
    IRequestHandler<GetMyRentalOrderMessagesQuery, List<RentalOrderMessageDto>>,
    IRequestHandler<SendMyRentalOrderMessageCommand, RentalOrderMessageDto>,
    IRequestHandler<GetMyRentalOrderThreadsQuery, List<RentalOrderThreadDto>>
{
    public Task<List<RentalOrderMessageDto>> Handle(GetRentalOrderMessagesQuery request, CancellationToken cancellationToken) =>
        ReadAsync(request.RentalOrderId, RentalAudience.Business, cancellationToken);

    public Task<RentalOrderMessageDto> Handle(SendRentalOrderMessageCommand request, CancellationToken cancellationToken) =>
        SendAsync(request.RentalOrderId, request.Body, RentalAudience.Business, cancellationToken);

    public Task<List<RentalOrderThreadDto>> Handle(GetRentalOrderThreadsQuery request, CancellationToken cancellationToken) =>
        ThreadsAsync(RentalAudience.Business, cancellationToken);

    public Task<List<RentalOrderMessageDto>> Handle(GetMyRentalOrderMessagesQuery request, CancellationToken cancellationToken) =>
        ReadAsync(request.RentalOrderId, RentalAudience.Customer, cancellationToken);

    public Task<RentalOrderMessageDto> Handle(SendMyRentalOrderMessageCommand request, CancellationToken cancellationToken) =>
        SendAsync(request.RentalOrderId, request.Body, RentalAudience.Customer, cancellationToken);

    public Task<List<RentalOrderThreadDto>> Handle(GetMyRentalOrderThreadsQuery request, CancellationToken cancellationToken) =>
        ThreadsAsync(RentalAudience.Customer, cancellationToken);

    private static RentalMessageSenderRole RoleOf(RentalAudience audience) =>
        audience == RentalAudience.Business ? RentalMessageSenderRole.Business : RentalMessageSenderRole.Customer;

    private static RentalMessageSenderRole OtherSide(RentalAudience audience) =>
        audience == RentalAudience.Business ? RentalMessageSenderRole.Customer : RentalMessageSenderRole.Business;

    private async Task<List<RentalOrderMessageDto>> ReadAsync(Guid orderId, RentalAudience audience, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(orderId, userId, audience, cancellationToken);

        // Reading the thread marks what the other side wrote as read.
        var otherSide = OtherSide(audience);
        var unread = await dbContext.RentalOrderMessages
            .Where(m => m.RentalOrderId == orderId && m.SenderRole == otherSide && m.ReadAt == null)
            .ToListAsync(cancellationToken);
        if (unread.Count > 0)
        {
            var now = clock.GetUtcNow();
            unread.ForEach(m => m.ReadAt = now);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var names = await NamesAsync(orderId, cancellationToken);

        // The latest stretch of the conversation, shown oldest first.
        var messages = await dbContext.RentalOrderMessages
            .AsNoTracking()
            .Where(m => m.RentalOrderId == orderId)
            .OrderByDescending(m => m.CreatedDate)
            .Take(settings.Value.MaxPageSize * 2)
            .ToListAsync(cancellationToken);

        return messages
            .OrderBy(m => m.CreatedDate)
            .Select(m => ToDto(m, audience, names))
            .ToList();
    }

    private async Task<RentalOrderMessageDto> SendAsync(Guid orderId, string body, RentalAudience audience, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        await dbContext.EnsureOrderAccessAsync(orderId, userId, audience, cancellationToken);

        // Sender and role come from the signed-in side, never from the request.
        var message = new RentalOrderMessage
        {
            RentalOrderId = orderId,
            SenderUserId = userId,
            SenderRole = RoleOf(audience),
            Body = body.Trim(),
        };
        dbContext.RentalOrderMessages.Add(message);
        await dbContext.SaveChangesAsync(cancellationToken);

        return ToDto(message, audience, (string.Empty, string.Empty));
    }

    private async Task<List<RentalOrderThreadDto>> ThreadsAsync(RentalAudience audience, CancellationToken cancellationToken)
    {
        var userId = currentUser.OwnerId();
        var messages = dbContext.RentalOrderMessages;
        var otherSide = OtherSide(audience);

        // One row per order that has messages, latest conversation first.
        var threads = await dbContext.OrdersOf(userId, audience)
            .AsNoTracking()
            .Where(o => messages.Any(m => m.RentalOrderId == o.Id))
            .Select(o => new
            {
                o.Id,
                o.CustomerName,
                BusinessName = dbContext.RentalBusinesses
                    .Where(b => b.OwnerUserId == o.OwnerUserId)
                    .Select(b => b.Name)
                    .FirstOrDefault(),
                ItemName = o.RentalItem.Name,
                o.Quantity,
                Last = messages
                    .Where(m => m.RentalOrderId == o.Id)
                    .OrderByDescending(m => m.CreatedDate)
                    .Select(m => new { m.Body, m.CreatedDate, m.SenderRole })
                    .First(),
                Unread = messages.Count(m => m.RentalOrderId == o.Id && m.SenderRole == otherSide && m.ReadAt == null),
            })
            .OrderByDescending(t => t.Last.CreatedDate)
            .Take(settings.Value.MaxPageSize)
            .ToListAsync(cancellationToken);

        return threads.Select(t => new RentalOrderThreadDto
        {
            RentalOrderId = t.Id,
            CustomerName = t.CustomerName,
            BusinessName = t.BusinessName,
            ItemName = t.ItemName,
            Quantity = t.Quantity,
            LastMessage = t.Last.Body,
            LastMessageAt = t.Last.CreatedDate,
            LastFromCustomer = t.Last.SenderRole == RentalMessageSenderRole.Customer,
            UnreadCount = t.Unread,
        }).ToList();
    }

    /// <summary>The customer's and the business's names on the order, for the bubbles.</summary>
    private async Task<(string Customer, string Business)> NamesAsync(Guid orderId, CancellationToken cancellationToken)
    {
        var names = await dbContext.RentalOrders
            .Where(o => o.Id == orderId)
            .Select(o => new
            {
                o.CustomerName,
                Business = dbContext.RentalBusinesses
                    .Where(b => b.OwnerUserId == o.OwnerUserId)
                    .Select(b => b.Name)
                    .FirstOrDefault(),
            })
            .FirstAsync(cancellationToken);
        return (names.CustomerName, names.Business ?? "Business");
    }

    private static RentalOrderMessageDto ToDto(
        RentalOrderMessage message, RentalAudience audience, (string Customer, string Business) names)
    {
        var mine = message.SenderRole == RoleOf(audience);
        return new RentalOrderMessageDto
        {
            Id = message.Id,
            RentalOrderId = message.RentalOrderId,
            SenderRole = message.SenderRole.ToString(),
            IsMine = mine,
            SenderName = mine
                ? "You"
                : message.SenderRole == RentalMessageSenderRole.Customer ? names.Customer : names.Business,
            Body = message.Body,
            SentAt = message.CreatedDate,
            ReadAt = message.ReadAt,
        };
    }
}
