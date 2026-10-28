using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.ValueObjects;

namespace Zuno.Application.Modules.Worker.DTOs;

/// <summary>
/// Turning a worker into what they are shown about themselves.
/// </summary>
/// <remarks>
/// One mapper, used by the profile endpoint and the dashboard alike, because the dashboard carries
/// the profile whole. Written by hand rather than through a mapper library, matching the rest of the
/// application layer.
/// </remarks>
public static class WorkerMappingExtensions
{
    /// <summary>
    /// The worker's own view of themselves.
    /// </summary>
    /// <param name="profile">Loaded with <c>User</c> and <c>PayoutDetail</c>; both are read here.</param>
    /// <param name="earnings">
    /// From <c>IWorkerEarningsService</c>. Passed in rather than computed here so the work-record
    /// rule stays in one place and a caller cannot accidentally ship a second version of it.
    /// </param>
    /// <param name="levels">The worker ladder from the platform settings.</param>
    public static WorkerProfileDto ToDto(
        this WorkerProfile profile,
        WorkerEarningsRollup earnings,
        LevelLadder levels)
    {
        var payout = profile.PayoutDetail;

        // Derived, not stored: there is nothing to keep in step, and a level that is recomputed on read
        // can never drift from the record behind it.
        var level = WorkerLevel.Calculate(
            levels, earnings.JobsCompleted, earnings.BusinessesWorkedFor, earnings.OffersDeclined);

        return new WorkerProfileDto
        {
            Id = profile.Id,
            FullName = $"{profile.User.FirstName} {profile.User.LastName}".Trim(),
            PhoneNumber = profile.User.PhoneNumber,
            Email = profile.User.Email ?? string.Empty,
            ExperienceYears = profile.ExperienceYears,
            HourlyRate = profile.HourlyRate,
            AvailabilityStatus = profile.AvailabilityStatus.ToString(),
            VerificationStatus = profile.VerificationStatus.ToString(),
            PhotoUrl = profile.PhotoUrl,

            Level = level,
            LevelName = levels.Name(level),
            JobsToNextLevel = WorkerLevel.JobsToNextLevel(
                levels, earnings.JobsCompleted, earnings.BusinessesWorkedFor, earnings.OffersDeclined),

            // What is actually in the way, which the job count alone stopped being able to say once
            // the level depended on more than jobs.
            NextLevelRequirement = WorkerLevel.NextLevelRequirement(
                levels, earnings.JobsCompleted, earnings.BusinessesWorkedFor, earnings.OffersDeclined),

            UpiVpa = payout?.UpiVpa,
            HasPayoutDestination = payout?.HasDestination ?? false,
            CanReceivePayouts = payout?.CanReceivePayouts ?? false,
            PayoutVerificationStatus =
                (payout?.VerificationStatus ?? VerificationStatus.Pending).ToString(),

            TotalEarned = earnings.TotalEarned,
            OwedToYou = earnings.OwedToYou,
            JobsCompleted = earnings.JobsCompleted,
            JobsPaid = earnings.JobsPaid,
            AverageSalary = earnings.AverageSalary,
            BusinessesWorkedFor = earnings.BusinessesWorkedFor,
            OffersDeclined = earnings.OffersDeclined,
            OpenDisputes = earnings.OpenDisputes,
        };
    }
}
