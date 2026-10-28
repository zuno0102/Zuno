namespace Zuno.Application.Common.Settings;

public class VerificationSettings
{
    public const string SectionName = "Verification";

    /// <summary>
    /// Whether a business is approved without a Super Admin: on sign-up, or on its next sign-in if it
    /// was still pending.
    /// </summary>
    /// <remarks>
    /// Either way a business must first pass the validation in <c>IBusinessVerificationCheck</c>:
    /// on, a business that passes is approved at once and one that does not waits for an admin; off
    /// (the default, and production), every business waits for an admin, whose approval is refused
    /// until it passes. See <c>BusinessApproval</c>.
    /// </remarks>
    public bool AutoVerifyBusinesses { get; set; }
}
