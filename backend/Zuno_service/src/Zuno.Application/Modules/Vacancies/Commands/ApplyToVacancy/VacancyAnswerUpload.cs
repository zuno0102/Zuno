namespace Zuno.Application.Modules.Vacancies.Commands.ApplyToVacancy;

/// <summary>What was sent for one requirement. Built by the controller from the multipart form.</summary>
/// <param name="Content">The uploaded file, positioned at its start and seekable. Documents only.</param>
public sealed record VacancyAnswerUpload(Guid RequirementId, string? Text, Stream? Content, long Length);
