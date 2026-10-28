using Zuno.Domain.Common;
using Zuno.Domain.Enums;

namespace Zuno.Domain.Entities;

/// <summary>
/// What an applicant sent for one requirement: a typed answer or an uploaded file.
/// </summary>
/// <remarks>
/// The requirement's wording is copied here, as <see cref="BookingServiceAnswer"/> does, so a business
/// rewording its form later never changes what an earlier applicant was asked.
/// </remarks>
public class VacancyApplicationAnswer : BaseEntity
{
    public Guid VacancyApplicationId { get; set; }

    public VacancyApplication VacancyApplication { get; set; } = null!;

    /// <summary>Back-pointer for reporting. Never read to render the answer.</summary>
    public Guid? VacancyRequirementId { get; set; }

    public VacancyRequirementKind Kind { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public string? AnswerText { get; set; }

    /// <summary>Where the file sits in private storage. Never a public URL.</summary>
    public string? FileKey { get; set; }

    /// <summary>The name offered when the business downloads it — built by the server, not the applicant's.</summary>
    public string? FileName { get; set; }

    public string? ContentType { get; set; }

    public long? FileSizeBytes { get; set; }

    public short SortOrder { get; set; }
}
