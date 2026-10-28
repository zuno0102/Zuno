namespace Zuno.Domain.Enums;

/// <summary>The kind of answer a business's custom field takes.</summary>
public enum VacancyRequirementKind : short
{
    /// <summary>Free text — "Which area do you live in?".</summary>
    Text = 1,

    /// <summary>A number — "Years of experience".</summary>
    Number = 2,

    /// <summary>Yes or No — "Do you have a two-wheeler?".</summary>
    YesNo = 3,

    /// <summary>An uploaded file — "Aadhaar", "Resume".</summary>
    File = 4,
}
