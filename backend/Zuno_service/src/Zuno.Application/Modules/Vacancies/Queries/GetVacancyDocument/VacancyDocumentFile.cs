namespace Zuno.Application.Modules.Vacancies.Queries.GetVacancyDocument;

/// <summary>The caller disposes <see cref="Content"/>; the controller hands it to the response.</summary>
public sealed record VacancyDocumentFile(Stream Content, string ContentType, string FileName);
