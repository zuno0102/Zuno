using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Booking.DTOs;

public static class BookingMappingExtensions
{
    /// <param name="viewerWorkerProfileId">Set when a worker is the viewer, to fill in their own row.</param>
    /// <param name="includeCrew">
    /// False for a customer. Staffing is the business's arrangement — a customer booked a
    /// service, not a headcount — and the crew list carries workers' names and phone numbers,
    /// which are not a customer's to have.
    /// </param>
    /// <param name="wages">
    /// What the crew is owed, from <see cref="Common.Interfaces.IBookingWageService"/>. Left null
    /// where a caller has not loaded it, which reports the wage fields as blank — an order that
    /// was never asked about is not an order that owes nothing.
    /// </param>
    public static BookingDto ToDto(
        this Domain.Entities.Booking booking,
        Guid? viewerWorkerProfileId = null,
        bool includeCrew = true,
        BookingWageRollup? wages = null) => new()
    {
        Id = booking.Id,
        Reference = booking.Reference,
        CrewStatus = includeCrew ? booking.CrewStatus.ToString() : string.Empty,
        ActiveCrewCount = includeCrew ? booking.ActiveCrewCount : 0,
        WorkStartedAt = booking.WorkStartedAt,
        // What the business pays its crew is between them; a customer sees none of it.
        WageStatus = includeCrew && wages is { } w ? w.Status.ToString() : string.Empty,
        WagePayeeCount = includeCrew ? wages?.PayeeCount ?? 0 : 0,
        WagePaidPayeeCount = includeCrew ? wages?.PaidPayeeCount ?? 0 : 0,
        WageTotalPayable = includeCrew ? wages?.TotalPayable ?? 0m : 0m,
        WageOutstandingAmount = includeCrew ? wages?.OutstandingAmount ?? 0m : 0m,
        BusinessOwnerProfileId = booking.BusinessOwnerProfileId,
        BusinessName = booking.BusinessOwnerProfile.BusinessName,
        BusinessLogoUrl = booking.BusinessOwnerProfile.LogoUrl,
        BusinessPhone = booking.BusinessOwnerProfile.User.PhoneNumber,
        CustomerProfileId = booking.CustomerProfileId,
        CustomerName = $"{booking.CustomerProfile.User.FirstName} {booking.CustomerProfile.User.LastName}",
        CustomerPhone = booking.CustomerProfile.User.PhoneNumber,
        BusinessServiceId = booking.BusinessServiceId,
        ServiceName = booking.BusinessService.Name,
        ServiceCategoryName = booking.BusinessService.ServiceCategory.Name,
        BusinessServiceVariantId = booking.BusinessServiceVariantId,
        VariantName = booking.BusinessServiceVariant?.Name,
        // The kind of work the order is actually for, carried by the package the customer chose.
        // A hiring post raised from this order starts from it rather than asking again.
        ServiceSubCategoryId = booking.BusinessServiceVariant?.ServiceSubCategoryId,
        ServiceSubCategoryName = booking.BusinessServiceVariant?.ServiceSubCategory?.Name,
        ImageUrl = booking.BusinessServiceVariant?.Media
                .Where(m => m.MediaType == ServiceMediaType.Image)
                .OrderBy(m => m.SortOrder)
                .FirstOrDefault()?.Url
            ?? booking.BusinessService.Media
                .Where(m => m.MediaType == ServiceMediaType.Image)
                .OrderBy(m => m.SortOrder)
                .FirstOrDefault()?.Url,
        RequiredWorkerCount = includeCrew ? booking.RequiredWorkerCount : 0,
        AssignedWorkers = includeCrew
            ? booking.WorkerAssignments
                .OrderBy(a => a.CreatedDate)
                .Select(a => new BookingWorkerAssignmentDto
                {
                    WorkerProfileId = a.WorkerProfileId,
                    WorkerName = $"{a.WorkerProfile.User.FirstName} {a.WorkerProfile.User.LastName}",
                    WorkerPhone = a.WorkerProfile.User.PhoneNumber,
                    Role = a.Role,
                    Status = a.AssignmentStatus.ToString(),
                    DisplayStatus = WorkerDisplayStatus(a.AssignmentStatus, booking),
                    AgreedSalaryAmount = a.AgreedSalaryAmount,
                    AgreedSalaryUnit = a.AgreedSalaryUnit?.ToString(),
                    PaymentStatus = a.PaymentStatus.ToString(),
                    // Null-safe: the payout detail is not always loaded, and an unloaded
                    // navigation must read as "unknown, do not promise", never as "ready to pay".
                    HasPayoutDetails = a.WorkerProfile.PayoutDetail != null,
                })
                .ToList()
            : [],
        MyAssignmentStatus = viewerWorkerProfileId is null
            ? null
            : booking.WorkerAssignments
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.AssignmentStatus.ToString(),
        MyRole = viewerWorkerProfileId is null
            ? null
            : booking.WorkerAssignments
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.Role,
        // The viewer's own wage, so their screens can say where their money stands without reading
        // the crew-wide roll-up — which is the business's figure and includes other people's wages.
        MyPaymentStatus = viewerWorkerProfileId is null
            ? null
            : booking.WorkerAssignments
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.PaymentStatus.ToString(),
        MyWageAmount = viewerWorkerProfileId is null
            ? null
            : booking.WorkerAssignments
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.AgreedSalaryAmount,
        Status = booking.BookingStatus.ToString(),
        ScheduledDate = booking.ScheduledDate,
        Notes = booking.Notes,
        PriceQuoted = booking.PriceQuoted,
        PriceType = booking.PriceType?.ToString(),
        ServiceAnswers = booking.ServiceAnswers.ToAnswerDtos(),
        // Sent to both sides unmasked: the crew size on the ORDER stays hidden from the customer,
        // but a number the customer is being asked to agree to is theirs to see by definition.
        AgreementStatus = booking.AgreementStatusOf(),
        Proposals = booking.AgreementProposals.ToProposalDtos(),
        AddressLine1 = booking.Address.Line1,
        City = booking.Address.City,
        State = booking.Address.State,
        PostalCode = booking.Address.PostalCode,
        CompletedAt = booking.CompletedAt,
        CancelledAt = booking.CancelledAt,
        CancellationReason = booking.CancellationReason,
        Rating = booking.Rating is null
            ? null
            : new RatingDto
            {
                Score = booking.Rating.Score,
                Comment = booking.Rating.Comment,
                CreatedDate = booking.Rating.CreatedDate,
            },
    };

    /// <summary>
    /// Where one worker stands, read against how far the work itself has got.
    /// </summary>
    /// <remarks>
    /// Someone who has accepted is <em>active</em> — on the job, not yet on site — until the
    /// business starts the work, at which point they are working. One row, two readings, so the
    /// assignment enum needs no extra value and no migration.
    /// </remarks>
    private static string WorkerDisplayStatus(
        BookingWorkerAssignmentStatus status,
        Domain.Entities.Booking booking) => status switch
    {
        BookingWorkerAssignmentStatus.Assigned => "Awaiting",
        BookingWorkerAssignmentStatus.Rejected => "Declined",
        BookingWorkerAssignmentStatus.Completed => "Completed",
        BookingWorkerAssignmentStatus.Accepted when booking.WorkStartedAt is not null
            => "InProgress",
        _ => "Active",
    };
}
