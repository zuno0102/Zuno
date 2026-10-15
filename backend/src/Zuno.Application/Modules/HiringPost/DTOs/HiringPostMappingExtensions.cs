using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.HiringPost.DTOs;

public static class HiringPostMappingExtensions
{
    /// <param name="viewerWorkerProfileId">
    /// Set when a worker is the viewer. It fills in their own application details and, just as
    /// importantly, withholds the full applicant list — the other applicants' names and phone
    /// numbers are the business's to see, not a rival applicant's.
    /// </param>
    public static HiringPostDto ToDto(this Domain.Entities.HiringPost post, Guid? viewerWorkerProfileId = null) => new()
    {
        Id = post.Id,
        BusinessOwnerProfileId = post.BusinessOwnerProfileId,
        BookingId = post.BookingId,
        BookingReference = BuildBookingReference(post),
        BookingStatus = post.Booking?.BookingStatus.ToString(),
        BusinessName = post.BusinessOwnerProfile.BusinessName,
        BusinessLogoUrl = post.BusinessOwnerProfile.LogoUrl,
        Title = post.Title,
        Description = post.Description,
        ImageUrl = post.ImageUrl,
        EventDate = post.EventDate,
        DurationMinutes = post.DurationMinutes,
        EventEndDate = post.EventEndDate,
        WorkStartedAt = post.WorkStartedAt,
        WorkCompletedAt = post.WorkCompletedAt,
        SettledAt = post.SettledAt,
        TotalPayable = post.TotalPayable,
        OutstandingAmount = post.OutstandingAmount,
        PayeeCount = post.PayeeCount,
        PaidPayeeCount = post.PaidPayeeCount,
        HasDisputedPayment = post.HasDisputedPayment,
        IsFullyComplete = post.IsFullyComplete,
        Location = post.Location,
        DistrictId = post.DistrictId,
        Latitude = post.Latitude,
        Longitude = post.Longitude,
        DistrictName = post.District?.Name,
        LocationPrecision = post.LocationPrecision.ToString(),
        // Filled in by the caller that knows where the worker is; the mapper cannot know.
        DistanceKm = null,
        ServiceSubCategoryId = post.ServiceSubCategoryId,
        ServiceSubCategoryName = post.ServiceSubCategory?.Name,
        WorkersNeeded = post.WorkersNeeded,
        SalaryAmount = post.SalaryAmount,
        SalaryUnit = post.SalaryUnit.ToString(),
        ConfirmedCount = post.ConfirmedCount,
        PendingOfferCount = post.PendingOfferCount,
        FilledCount = post.FilledCount,
        Status = post.HiringPostStatus.ToString(),
        CreatedDate = post.CreatedDate,
        MyApplicationStatus = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.ApplicationStatus.ToString(),
        MyApplicationId = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.Id,
        MyAgreedSalaryAmount = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.AgreedSalaryAmount,
        MyPaymentStatus = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.PaymentStatus.ToString(),
        MyPaidAt = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.PaidAt,
        MyDisputeReason = viewerWorkerProfileId is null
            ? null
            : post.Applications
                .FirstOrDefault(a => a.WorkerProfileId == viewerWorkerProfileId)
                ?.DisputeReason,
        // Withheld from worker viewers: one applicant has no business seeing the contact
        // details of everyone else who applied for the same job.
        Applications = viewerWorkerProfileId is not null
            ? []
            : post.Applications
            .OrderBy(a => a.CreatedDate)
            .Select(a => new HiringPostApplicationDto
            {
                Id = a.Id,
                WorkerProfileId = a.WorkerProfileId,
                WorkerName = $"{a.WorkerProfile.User.FirstName} {a.WorkerProfile.User.LastName}",
                WorkerPhone = a.WorkerProfile.User.PhoneNumber,
                Status = a.ApplicationStatus.ToString(),
                AppliedAt = a.CreatedDate,
                WorkerRespondedAt = a.WorkerRespondedAt,
                AgreedSalaryAmount = a.AgreedSalaryAmount,
                AgreedSalaryUnit = a.AgreedSalaryUnit?.ToString(),
                PaymentStatus = a.PaymentStatus.ToString(),
                PaidAt = a.PaidAt,
                DisputeReason = a.DisputeReason,
                SalaryAdjustments = a.SalaryAdjustments
                    .OrderBy(adj => adj.CreatedDate)
                    .Select(adj => new HiringPostSalaryAdjustmentDto
                    {
                        Id = adj.Id,
                        PreviousAmount = adj.PreviousAmount,
                        NewAmount = adj.NewAmount,
                        Reason = adj.Reason,
                        AdjustedAt = adj.CreatedDate,
                    })
                    .ToList(),
            })
            .ToList(),
    };

    /// <summary>
    /// "#7A3F91C2 · Catering · 28 Sep" for a post raised against an order, null otherwise.
    /// </summary>
    /// <remarks>
    /// Returns null when the booking navigation was not loaded rather than guessing, so a caller
    /// that forgot the Include shows nothing instead of something wrong.
    /// </remarks>
    private static string? BuildBookingReference(Domain.Entities.HiringPost post)
    {
        if (post.Booking?.BusinessService is not { } service)
        {
            return null;
        }

        var when = post.Booking.ScheduledDate.ToLocalTime();
        return $"{post.Booking.Reference} · {service.Name} · {when.Day} {MonthNames[when.Month - 1]}";
    }

    private static readonly string[] MonthNames =
    [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
}
