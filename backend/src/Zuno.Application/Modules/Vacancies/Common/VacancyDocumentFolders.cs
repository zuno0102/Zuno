namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>
/// Where a vacancy's documents live in private storage. One folder per application inside one per
/// vacancy, so deleting either removes exactly its own files.
/// </summary>
public static class VacancyDocumentFolders
{
    public static string ForVacancy(Guid vacancyId) => $"vacancies/{vacancyId:N}";

    public static string ForApplication(Guid vacancyId, Guid applicationId) =>
        $"{ForVacancy(vacancyId)}/{applicationId:N}";
}
