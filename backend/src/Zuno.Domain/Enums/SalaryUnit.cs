namespace Zuno.Domain.Enums;

/// <summary>
/// What a hiring post's salary figure is measured against, so a worker can tell
/// "₹800" for a whole event apart from "₹800" an hour before applying.
/// </summary>
public enum SalaryUnit : short
{
    PerEvent = 1,
    PerDay = 2,
    PerHour = 3,
}
