namespace Zuno.Domain.Enums;

/// <summary>Where a full-time vacancy stands. Expiry is not a status — it is read off <c>ExpiresAt</c>.</summary>
public enum VacancyStatus : short
{
    /// <summary>Written but not paid for. Workers never see it.</summary>
    AwaitingPayment = 1,

    /// <summary>Paid and taking applications until its listing period ends.</summary>
    Open = 2,

    /// <summary>The business paused hiring. Hidden from workers; can be reopened while still paid for.</summary>
    Stopped = 3,
}
