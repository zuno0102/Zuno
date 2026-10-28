namespace Zuno.Domain.Enums;

/// <summary>What a vacancy's salary figure is counted per. Separate from <see cref="SalaryUnit"/>, which is per event.</summary>
public enum VacancyPayPeriod : short
{
    PerDay = 1,
    PerWeek = 2,
    PerMonth = 3,
}
