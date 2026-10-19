namespace Zuno.Application.Common.Settings;

public class VerificationSettings
{
    public const string SectionName = "Verification";

    /// <summary>
    /// Skips the Super Admin review: a business is Verified as soon as it registers, and a Pending
    /// one is Verified the next time it signs in.
    /// </summary>
    /// <remarks>
    /// A stopgap for real-world testing until the admin verification screen exists — without it, a
    /// new business stays Pending and no customer can ever see or book its services. Off by
    /// default; turn it off again once an admin is reviewing businesses, because while it is on,
    /// anyone who signs up as a business is shown to customers unchecked.
    /// </remarks>
    public bool AutoVerifyBusinesses { get; set; }
}
