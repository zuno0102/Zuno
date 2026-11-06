using Zuno.Rent.Domain.Common;

namespace Zuno.Rent.Domain.Entities;

/// <summary>
/// A customer's mobile number checked with a one-time code before they book a rent item — so a
/// booking that holds a business's stock comes from a number somebody really answers. One row per
/// customer and number: once verified, later bookings with that number need no new code.
/// </summary>
public class RentalPhoneVerification : BaseEntity
{
    public Guid CustomerUserId { get; set; }

    /// <summary>The 10 digits of the mobile, as <c>RentalPhone.Normalize</c> keeps it.</summary>
    public string Phone { get; set; } = string.Empty;

    /// <summary>A hash of the code last sent; null once the number is verified. The code itself is never stored.</summary>
    public string? CodeHash { get; set; }

    public DateTimeOffset? CodeExpiresAt { get; set; }

    /// <summary>Wrong codes typed against the code last sent.</summary>
    public int Attempts { get; set; }

    public DateTimeOffset? LastSentAt { get; set; }

    /// <summary>When the hour of sends being counted started — so one number cannot be sent code after code.</summary>
    public DateTimeOffset? SendWindowStartedAt { get; set; }

    public int SendsInWindow { get; set; }

    public DateTimeOffset? VerifiedAt { get; set; }

    /// <summary>
    /// Changed on every write and checked on save, so two requests at once cannot both pass the same
    /// count: of a burst of guesses against one code, only one is counted at a time, and the rest are
    /// turned away instead of each getting a free try.
    /// </summary>
    public Guid ConcurrencyStamp { get; set; } = Guid.NewGuid();
}

/// <summary>The shape of a verification, used the same way by the code and the database.</summary>
public static class RentalPhoneVerificationFields
{
    public const int PhoneLength = 10;

    public const int CodeHashMaxLength = 128;
}
