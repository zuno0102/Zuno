namespace Zuno.Domain.Enums;

public enum BookingStatus : short
{
    Pending = 1,
    Assigned = 2,
    InProgress = 3,
    Completed = 4,
    Cancelled = 5,
    Confirmed = 6,
}
