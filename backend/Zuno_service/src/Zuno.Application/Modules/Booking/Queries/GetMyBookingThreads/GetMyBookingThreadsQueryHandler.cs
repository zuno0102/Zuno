using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.Common;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Booking.Queries.GetMyBookingThreads;

public class GetMyBookingThreadsQueryHandler(
    ICurrentUserService currentUserService,
    IApplicationDbContext dbContext)
    : IRequestHandler<GetMyBookingThreadsQuery, List<BookingThreadDto>>
{
    public async Task<List<BookingThreadDto>> Handle(
        GetMyBookingThreadsQuery request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        // Which side of their own bookings this person is on. Both are checked rather than reading
        // the role claim: one account could in principle hold both profiles, and the booking itself
        // is the authority on who is party to it.
        var rows = await dbContext.Bookings
            .Where(b => b.CustomerProfile.UserId == userId
                || b.BusinessOwnerProfile.UserId == userId)
            .Select(b => new
            {
                b.Id,
                b.ScheduledDate,
                b.BookingStatus,
                HasRating = b.Rating != null,
                // This person's own clearing of the thread, if any. The other party's is irrelevant
                // to what they see.
                ClearedAt = b.ThreadClears
                    .Where(c => c.UserId == userId)
                    .Select(c => (DateTimeOffset?)c.ClearedAt)
                    .FirstOrDefault(),
                Title = b.BusinessServiceVariant != null
                    ? b.BusinessServiceVariant.Name
                    : b.BusinessService.Name,
                IsCustomer = b.CustomerProfile.UserId == userId,
                BusinessName = b.BusinessOwnerProfile.BusinessName,
                BusinessLogoUrl = b.BusinessOwnerProfile.LogoUrl,
                CustomerName = b.CustomerProfile.User.FirstName + " " + b.CustomerProfile.User.LastName,
                Messages = b.Messages
                    .OrderByDescending(m => m.CreatedDate)
                    .Select(m => new
                    {
                        m.Body,
                        m.CreatedDate,
                        m.SenderRole,
                        m.ReadAt,
                    })
                    .ToList(),
            })
            .ToListAsync(cancellationToken);

        var threads = rows
            // Cancelled and not-yet-confirmed orders are left out: the conversation opens when the
            // business takes the order on and closes if it is called off, so a thread here would be
            // one somebody could open and not be allowed to answer.
            .Where(r => BookingThreadAccess.CanMessage(r.BookingStatus, r.HasRating))
            .Select(r => new
            {
                Row = r,
                // Only what this person has not cleared. A thread they cleared comes back the moment
                // somebody writes again, because clearing says "I am done with this", not "never
                // speak to me about this order".
                Visible = r.ClearedAt is null
                    ? r.Messages
                    : r.Messages.Where(m => m.CreatedDate > r.ClearedAt).ToList(),
            })
            // A booking nobody has written on is not a conversation. It appears here the moment
            // either side says something, which is also how a customer starts one — from the booking
            // itself, not from an empty list of every order they have ever placed.
            .Where(x => x.Visible.Count > 0)
            .Select(x =>
            {
                var r = x.Row;
                var mine = r.IsCustomer ? BookingPartyRole.Customer : BookingPartyRole.Business;
                var last = x.Visible[0];

                return new BookingThreadDto
                {
                    BookingId = r.Id,
                    Title = r.Title,
                    CounterpartName = r.IsCustomer ? r.BusinessName : r.CustomerName.Trim(),
                    // Only a business has a logo; a customer shows as initials on the other side.
                    CounterpartLogoUrl = r.IsCustomer ? r.BusinessLogoUrl : null,
                    ScheduledDate = r.ScheduledDate,
                    BookingStatus = r.BookingStatus.ToString(),
                    LastMessage = last.Body,
                    LastMessageAt = last.CreatedDate,
                    LastMessageIsMine = last.SenderRole == mine,
                    UnreadCount = x.Visible
                        .Count(m => m.SenderRole != mine && m.ReadAt is null),
                };
            })
            // Newest activity first, which is where somebody opening this screen is looking.
            .OrderByDescending(t => t.LastMessageAt)
            .ToList();

        return threads;
    }
}
