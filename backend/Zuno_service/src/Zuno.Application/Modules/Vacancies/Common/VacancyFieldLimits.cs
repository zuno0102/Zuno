namespace Zuno.Application.Modules.Vacancies.Common;

/// <summary>Text lengths on a full-time job post. Match the column sizes in <c>VacancyConfiguration</c>.</summary>
public static class VacancyFieldLimits
{
    public const int MaxTitleLength = 150;
    public const int MaxDescriptionLength = 2000;
    public const int MaxLocationLength = 300;
    public const int MaxPromptLength = 200;
}
