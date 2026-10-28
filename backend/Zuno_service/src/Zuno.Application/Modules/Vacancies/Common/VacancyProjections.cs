using System.Linq.Expressions;
using Zuno.Application.Modules.Vacancies.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;

namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>
/// The one shape every vacancy read returns, as SQL projections rather than loaded entities.
/// </summary>
/// <remarks>
/// Shared by the business list, the worker feed and both detail reads, so a field added here reaches
/// every screen and no two queries disagree about what "live" means. Each runs as one round trip that
/// selects only these columns.
/// </remarks>
public static class VacancyProjections
{
    /// <param name="workerProfileId">The worker reading, so their own application rides along. Null for the business.</param>
    public static Expression<Func<Vacancy, VacancyDto>> ToDto(Guid? workerProfileId, DateTimeOffset now) => v => new VacancyDto
    {
        Id = v.Id,
        BusinessOwnerProfileId = v.BusinessOwnerProfileId,
        BusinessName = v.BusinessOwnerProfile.BusinessName,
        BusinessLogoUrl = v.BusinessOwnerProfile.LogoUrl,
        Title = v.Title,
        Description = v.Description,
        JobTypeId = v.VacancyJobTypeId,
        JobTypeName = v.VacancyJobType.Name,
        ServiceSubCategoryId = v.ServiceSubCategoryId,
        ServiceSubCategoryName = v.ServiceSubCategory != null ? v.ServiceSubCategory.Name : null,
        Openings = v.Openings,
        SalaryMin = v.SalaryMin,
        SalaryMax = v.SalaryMax,
        PayPeriod = v.PayPeriod,
        WorkingDaysPerWeek = v.WorkingDaysPerWeek,
        ShiftStart = v.ShiftStart,
        ShiftEnd = v.ShiftEnd,
        ContractMonths = v.ContractMonths,
        Location = v.Location,
        DistrictName = v.District != null ? v.District.Name : null,
        Latitude = v.Latitude,
        Longitude = v.Longitude,
        Status = v.VacancyStatus,
        // The same three rules as the entity's methods, spelled out because SQL cannot call them.
        IsLive = v.VacancyStatus == VacancyStatus.Open && v.ExpiresAt > now,
        NeedsPayment = v.VacancyStatus == VacancyStatus.AwaitingPayment || v.ExpiresAt == null || v.ExpiresAt <= now,
        CanResume = v.VacancyStatus == VacancyStatus.Stopped && v.ExpiresAt > now,
        FeeAmount = v.FeeAmount,
        PublishedAt = v.PublishedAt,
        ExpiresAt = v.ExpiresAt,
        HiringStoppedAt = v.HiringStoppedAt,
        CreatedDate = v.CreatedDate,
        // Rejected applicants have left every business list, so they are not counted on it either.
        ApplicantCount = v.Applications.Count(a => a.ApplicationStatus != VacancyApplicationStatus.Rejected),
        NewCount = v.Applications.Count(a => a.ApplicationStatus == VacancyApplicationStatus.Applied),
        WaitingCount = v.Applications.Count(a => a.ApplicationStatus == VacancyApplicationStatus.Viewed),
        ShortlistedCount = v.Applications.Count(a => a.ApplicationStatus == VacancyApplicationStatus.Shortlisted),
        HiredCount = v.Applications.Count(a => a.ApplicationStatus == VacancyApplicationStatus.Hired),
        Requirements = v.Requirements
            .OrderBy(r => r.SortOrder)
            .Select(r => new VacancyRequirementDto
            {
                Id = r.Id,
                Kind = r.Kind,
                Prompt = r.Prompt,
                IsRequired = r.IsRequired,
                SortOrder = r.SortOrder,
            })
            .ToList(),
        MyApplicationId = v.Applications
            .Where(a => a.WorkerProfileId == workerProfileId)
            .Select(a => (Guid?)a.Id)
            .FirstOrDefault(),
        MyApplicationStatus = v.Applications
            .Where(a => a.WorkerProfileId == workerProfileId)
            .Select(a => (VacancyApplicationStatus?)a.ApplicationStatus)
            .FirstOrDefault(),
        MyAppliedAt = v.Applications
            .Where(a => a.WorkerProfileId == workerProfileId)
            .Select(a => (DateTimeOffset?)a.CreatedDate)
            .FirstOrDefault(),
    };

    public static Expression<Func<VacancyApplication, VacancyApplicationDto>> ToApplicationDto => a => new VacancyApplicationDto
    {
        Id = a.Id,
        VacancyId = a.VacancyId,
        VacancyTitle = a.Vacancy.Title,
        WorkerProfileId = a.WorkerProfileId,
        WorkerName = a.WorkerProfile.User.FirstName + " " + a.WorkerProfile.User.LastName,
        WorkerPhone = a.WorkerProfile.User.PhoneNumber,
        WorkerPhotoUrl = a.WorkerProfile.PhotoUrl ?? a.WorkerProfile.User.ProfileImageUrl,
        ExperienceYears = a.WorkerProfile.ExperienceYears,
        Status = a.ApplicationStatus,
        AppliedAt = a.CreatedDate,
        StatusChangedAt = a.StatusChangedAt,
        BusinessNote = a.BusinessNote,
        Answers = a.Answers
            .OrderBy(x => x.SortOrder)
            .Select(x => new VacancyApplicationAnswerDto
            {
                Id = x.Id,
                Kind = x.Kind,
                Prompt = x.Prompt,
                AnswerText = x.AnswerText,
                HasFile = x.FileKey != null,
                FileName = x.FileName,
                ContentType = x.ContentType,
                FileSizeBytes = x.FileSizeBytes,
                SortOrder = x.SortOrder,
            })
            .ToList(),
    };
}
