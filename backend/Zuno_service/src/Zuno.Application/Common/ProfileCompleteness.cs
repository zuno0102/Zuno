namespace Zuno.Application.Common;

/// <summary>
/// What a business or worker profile still needs before it is complete, in words the app shows
/// ("Add your UPI ID"). One rule for both roles: a UPI ID, because without one a business cannot show
/// a payment QR and a worker cannot be paid wages.
/// </summary>
public static class ProfileCompleteness
{
    public const string UpiId = "UPI ID";

    /// <summary>The details still missing; empty when the profile is complete.</summary>
    public static List<string> Missing(string? upiId) =>
        string.IsNullOrWhiteSpace(upiId) ? [UpiId] : [];
}
