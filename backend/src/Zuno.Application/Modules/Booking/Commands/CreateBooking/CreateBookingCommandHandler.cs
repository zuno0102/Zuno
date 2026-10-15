using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Booking.DTOs;
using Zuno.Application.Modules.Booking.Events;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Booking.Commands.CreateBooking;

public class CreateBookingCommandHandler(
    ICurrentUserService currentUserService,
    IBookingRepository bookingRepository,
    IApplicationDbContext dbContext,
    IPublisher publisher) : IRequestHandler<CreateBookingCommand, BookingDto>
{
    public async Task<BookingDto> Handle(CreateBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var customerProfile = await dbContext.CustomerProfiles
            .Include(cp => cp.User)
            .FirstOrDefaultAsync(cp => cp.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(CustomerProfile), userId);

        var service = await dbContext.BusinessServices
            .Include(s => s.ServiceCategory)
            .Include(s => s.Questions)
            .Include(s => s.BusinessOwnerProfile).ThenInclude(bp => bp.User)
            .FirstOrDefaultAsync(
                s => s.Id == request.BusinessServiceId
                    && s.IsActive
                    && s.BusinessOwnerProfile.VerificationStatus == VerificationStatus.Verified,
                cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.BusinessServiceId);

        BusinessServiceVariant? variant = null;
        if (request.BusinessServiceVariantId.HasValue)
        {
            variant = await dbContext.BusinessServiceVariants
                .FirstOrDefaultAsync(v => v.Id == request.BusinessServiceVariantId.Value, cancellationToken)
                ?? throw new EntityNotFoundException(nameof(BusinessServiceVariant), request.BusinessServiceVariantId.Value);
        }

        var address = new Address
        {
            OwnerUserId = userId,
            Label = "Service address",
            Line1 = request.AddressLine1,
            Line2 = request.AddressLine2,
            City = request.City,
            State = request.State,
            PostalCode = request.PostalCode,
            Country = request.Country ?? "India",
            Latitude = request.Latitude,
            Longitude = request.Longitude,
        };
        dbContext.Addresses.Add(address);

        if (customerProfile.DefaultAddressId is null)
        {
            customerProfile.DefaultAddressId = address.Id;
            customerProfile.DefaultAddress = address;
        }

        var booking = new Domain.Entities.Booking
        {
            CustomerProfileId = customerProfile.Id,
            CustomerProfile = customerProfile,
            BusinessOwnerProfileId = service.BusinessOwnerProfileId,
            BusinessOwnerProfile = service.BusinessOwnerProfile,
            BusinessServiceId = service.Id,
            BusinessService = service,
            BusinessServiceVariantId = variant?.Id,
            BusinessServiceVariant = variant,
            Address = address,
            AddressId = address.Id,
            ScheduledDate = request.ScheduledDate,
            Notes = request.Notes,
            PriceQuoted = variant?.Price ?? service.Price,
            // Taken from whichever row the price came from, so the two always describe each other.
            // A variant may be priced differently from its parent service, including per person.
            PriceType = variant?.PriceType ?? service.PriceType,
            // Zero for a per-person service, meaning "agreed with the customer for this order"
            // rather than "nobody needed". The crew size is settled before the order is confirmed.
            RequiredWorkerCount = service.RequiredWorkerCount,
            BookingStatus = BookingStatus.Pending,
        };

        AttachAnswers(booking, service, request.Answers);

        bookingRepository.Add(booking);
        await dbContext.SaveChangesAsync(cancellationToken);

        await publisher.Publish(
            new BookingCreatedEvent(
                booking.Id,
                service.BusinessOwnerProfile.UserId,
                service.BusinessOwnerProfile.User.Email,
                service.Name,
                booking.ScheduledDate),
            cancellationToken);

        return booking.ToDto(includeCrew: false);
    }

    /// <summary>
    /// Records the customer's answers, copying each question's wording onto the answer.
    /// </summary>
    /// <remarks>
    /// The copy is the point. A business may reword, reorder or retire a question tomorrow, and
    /// none of that may change what an order taken today says it was told — the same discipline
    /// <c>PriceQuoted</c> already follows by snapshotting the price rather than reading it live.
    ///
    /// Answers whose question does not belong to this service are dropped rather than trusted:
    /// the question id arrives from the client, and a stray one would write someone else's
    /// question onto this order. The validator refuses them outright; this is the second lock.
    /// </remarks>
    private static void AttachAnswers(
        Domain.Entities.Booking booking,
        BusinessService service,
        List<BookingAnswerInput> answers)
    {
        var questionsById = service.Questions.ToDictionary(q => q.Id);

        foreach (var answer in answers)
        {
            if (!questionsById.TryGetValue(answer.QuestionId, out var question))
            {
                continue;
            }

            var text = answer.AnswerText.Trim();
            if (text.Length == 0)
            {
                continue;
            }

            booking.ServiceAnswers.Add(new BookingServiceAnswer
            {
                BusinessServiceQuestionId = question.Id,
                QuestionPrompt = question.Prompt,
                AnswerText = text,
                SortOrder = question.SortOrder,
            });
        }
    }
}
