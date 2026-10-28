using Zuno.Domain.Common;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Domain.Entities;

/// <summary>A worker's application to a vacancy, with what they sent in answer to its fields.</summary>
public class VacancyApplication : BaseEntity
{
    public Guid VacancyId { get; set; }

    public Vacancy Vacancy { get; set; } = null!;

    public Guid WorkerProfileId { get; set; }

    public WorkerProfile WorkerProfile { get; set; } = null!;

    public VacancyApplicationStatus ApplicationStatus { get; set; } = VacancyApplicationStatus.Applied;

    public DateTimeOffset? StatusChangedAt { get; set; }

    /// <summary>The business's private note about this applicant. Never shown to the worker.</summary>
    public string? BusinessNote { get; set; }

    public ICollection<VacancyApplicationAnswer> Answers { get; set; } = new List<VacancyApplicationAnswer>();

    /// <summary>The decisions a business can make. Applied and Viewed are reached only by applying and opening.</summary>
    public static bool IsDecision(VacancyApplicationStatus status) =>
        status is VacancyApplicationStatus.Shortlisted
            or VacancyApplicationStatus.Hired
            or VacancyApplicationStatus.Rejected;

    /// <summary>
    /// The business opened the application. Moves it from New to Waiting the first time; any later
    /// opening, or opening one already decided, changes nothing.
    /// </summary>
    /// <returns>Whether anything changed.</returns>
    public bool MarkViewed(DateTimeOffset now)
    {
        if (ApplicationStatus != VacancyApplicationStatus.Applied)
        {
            return false;
        }

        ApplicationStatus = VacancyApplicationStatus.Viewed;
        StatusChangedAt = now;
        return true;
    }

    /// <summary>
    /// Records the business's decision. Rejecting is final and deletes what the worker sent: the
    /// business has no further use for an Aadhaar copy it has turned down.
    /// </summary>
    /// <returns>Whether the status changed.</returns>
    public bool Decide(VacancyApplicationStatus decision, DateTimeOffset now)
    {
        if (!IsDecision(decision))
        {
            throw new DomainException("Choose Shortlist, Hire or Reject.");
        }

        if (ApplicationStatus == VacancyApplicationStatus.Rejected)
        {
            throw new DomainException("This applicant was rejected, and what they sent has been deleted.");
        }

        if (ApplicationStatus == decision)
        {
            return false;
        }

        ApplicationStatus = decision;
        StatusChangedAt = now;

        if (decision == VacancyApplicationStatus.Rejected)
        {
            BusinessNote = null;
            ClearAnswers();
        }

        return true;
    }

    /// <summary>
    /// Wipes everything the applicant sent and marks the application deleted. Used when the worker
    /// withdraws or the vacancy is deleted. The files themselves are removed by the caller, from storage.
    /// </summary>
    public void ErasePersonalData()
    {
        BusinessNote = null;
        ClearAnswers();
        IsDeleted = true;
    }

    private void ClearAnswers()
    {
        foreach (var answer in Answers)
        {
            answer.AnswerText = null;
            answer.FileKey = null;
            answer.FileName = null;
            answer.IsDeleted = true;
        }
    }
}
